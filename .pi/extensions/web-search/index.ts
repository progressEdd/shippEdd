/**
 * web-search — dual-engine web search for pi
 *
 * Tools:
 *   web_search      — DuckDuckGo (ddgs, free) with automatic fallback to the
 *                     GLM search-prime MCP engine when DDG fails or gets
 *                     rate-limited. A consecutive-failure circuit breaker
 *                     routes straight to GLM during cooldown windows.
 *   glm_web_search  — GLM search-prime directly (z.ai Web Search MCP Server,
 *                     included with the GLM Coding Plan; metered to plan
 *                     quota). Adds domain + recency filters. Use for premium
 *                     quality or when explicitly requested.
 *
 * Engines live in ./ddg.ts (DuckDuckGo via ddgs Python lib) and ./glm.ts
 * (z.ai MCP over Streamable HTTP, no SDK). Shared cache/formatting in
 * ./types.ts.
 *
 * DDG engine adapted from SchneiderDaniel/cheasee-pi web-search (MIT).
 * GLM engine per https://docs.z.ai/devpack/mcp/search-mcp-server
 */

import {
	getMarkdownTheme,
	type ExtensionAPI,
} from "@earendil-works/pi-coding-agent";
import { StringEnum } from "@earendil-works/pi-ai";
import { Markdown, Text } from "@earendil-works/pi-tui";
import { Type } from "typebox";
import { ddgSearch } from "./ddg.ts";
import { glmSearch } from "./glm.ts";
import {
	cacheGet,
	cacheKeyFor,
	cacheSet,
	formatResults,
	type SearchResult,
} from "./types.ts";

// ── Routing state: DDG failure circuit breaker ─────────────────────────────

/** Consecutive DDG failures before entering GLM-preferred cooldown. */
const DDG_FAILURE_THRESHOLD = 3;
/** How long to skip DDG after the breaker trips. */
const DDG_COOLDOWN_MS = 10 * 60 * 1000;

let ddgConsecutiveFailures = 0;
let ddgCooldownUntil = 0;

function ddgInCooldown(): boolean {
	return Date.now() < ddgCooldownUntil;
}

function noteDdgFailure(): void {
	ddgConsecutiveFailures++;
	if (ddgConsecutiveFailures >= DDG_FAILURE_THRESHOLD) {
		ddgCooldownUntil = Date.now() + DDG_COOLDOWN_MS;
	}
}

function noteDdgSuccess(): void {
	ddgConsecutiveFailures = 0;
	ddgCooldownUntil = 0;
}

// ── Shared tool pieces ──────────────────────────────────────────────────────

const Recency = StringEnum(["oneDay", "oneWeek", "oneMonth", "oneYear", "noLimit"] as const, {
	description: "Time range for results: oneDay, oneWeek, oneMonth, oneYear, or noLimit (default).",
});

const QuerySchema = Type.String({ description: "Search query" });

const MaxResultsSchema = Type.Optional(
	Type.Integer({ description: "Number of results to return (default 10)", minimum: 1, maximum: 50 }),
);

function renderResult(result: any, { expanded }: { expanded: boolean }, theme: any) {
	const text = result.content[0];
	const plain = text?.type === "text" ? text.text : "(no results)";
	if (expanded) {
		return new Markdown(plain, 0, 0, getMarkdownTheme());
	}
	const details = result.details as { results?: SearchResult[]; engine?: string } | undefined;
	const count = details?.results?.length ?? 0;
	const engine = details?.engine === "glm-mcp" ? " · glm" : "";
	const header =
		theme.fg("toolTitle", theme.bold("web_search ")) +
		theme.fg("accent", `${count} results${engine}`);
	const preview = plain.split("\n").slice(0, 3).join("\n");
	return new Text(`${header}\n${theme.fg("toolOutput", preview)}`, 0, 0);
}

async function resolveGlmKey(ctx: any): Promise<string> {
	const apiKey = await ctx.modelRegistry.getApiKeyForProvider("zai");
	if (!apiKey) {
		throw new Error(
			"no zai API key configured for GLM search. Run /login for the zai provider.",
		);
	}
	return apiKey;
}

// ── Extension ───────────────────────────────────────────────────────────────

export default function webSearch(pi: ExtensionAPI): void {
	// Primary tool: DuckDuckGo with GLM fallback
	pi.registerTool({
		name: "web_search",
		label: "Web Search",
		description:
			"Search the web and return ranked results (title, URL, snippet) via DuckDuckGo, " +
			"automatically falling back to GLM search-prime when DuckDuckGo fails or is rate-limited. " +
			"Free by default; the fallback engine is billed to the GLM Coding Plan quota. " +
			"Results are cached for 5 minutes.",
		promptSnippet: "Search the web and return ranked results with URLs and snippets",
		promptGuidelines: [
			"Use web_search when you need current information, documentation, or URLs you haven't seen.",
			"web_search runs on DuckDuckGo first and falls back to GLM automatically — no need to choose an engine.",
			"For domain-restricted or time-filtered searches, use glm_web_search which supports those filters.",
		],
		parameters: Type.Object({
			query: QuerySchema,
			maxResults: MaxResultsSchema,
		}),

		async execute(_toolCallId, params, signal, onUpdate, ctx) {
			const query = params.query.trim();
			if (!query) throw new Error("web_search: query must not be empty");
			const maxResults = Math.min(50, Math.max(1, params.maxResults ?? 10));

			const key = cacheKeyFor(["any", query, maxResults]);
			const cached = cacheGet(key);
			if (cached) {
				return {
					content: [{ type: "text", text: formatResults(cached.results) }],
					details: { results: cached.results, engine: cached.engine, cached: true },
				};
			}

			let results: SearchResult[] | undefined;
			let engine: string | undefined;
			let fallbackReason: string | undefined;

			// 1) DuckDuckGo (skipped during cooldown)
			if (!ddgInCooldown()) {
				try {
					results = await ddgSearch(query, maxResults, signal, (msg) =>
						onUpdate?.({ content: [{ type: "text", text: msg }], details: {} }),
					);
					if (results.length === 0) {
						fallbackReason = "ddg returned no results";
						noteDdgFailure();
					} else {
						engine = "ddg";
						noteDdgSuccess();
					}
				} catch (err) {
					if (signal?.aborted) throw err;
					fallbackReason = `ddg failed: ${(err as Error).message.slice(0, 200)}`;
					noteDdgFailure();
				}
			} else {
				fallbackReason = "ddg cooldown (recent rate-limiting)";
			}

			// 2) GLM fallback
			if (!engine) {
				onUpdate?.({
					content: [{ type: "text", text: `Falling back to GLM search (${fallbackReason})…` }],
					details: {},
				});
				const apiKey = await resolveGlmKey(ctx);
				results = await glmSearch(apiKey, { query, maxResults }, signal);
				engine = "glm-mcp";
			}

			cacheSet(key, results, engine === "ddg" ? "ddg" : "glm-mcp");
			return {
				content: [{ type: "text", text: formatResults(results) }],
				details: { results, engine, cached: false, fallbackReason },
			};
		},

		renderResult,
	});

	// Premium tool: GLM search-prime directly
	pi.registerTool({
		name: "glm_web_search",
		label: "GLM Web Search",
		description:
			"Search the web via GLM search-prime (z.ai premium engine, billed to the GLM Coding Plan quota). " +
			"Returns ranked results with title, URL, snippet, site name, and publish date. " +
			"Supports domain filtering and recency filters. Use for higher-quality results than " +
			"DuckDuckGo, domain/time-restricted queries, or when the user explicitly asks for GLM search.",
		promptSnippet: "Premium web search via GLM with domain and recency filters",
		promptGuidelines: [
			"Use glm_web_search when web_search results are insufficient, or for domain-restricted (domains) and time-filtered (recency) searches.",
			"glm_web_search results include site names and publish dates — prefer it for research where provenance matters.",
			"glm_web_search consumes GLM Coding Plan quota; default to web_search for routine lookups.",
		],
		parameters: Type.Object({
			query: QuerySchema,
			maxResults: MaxResultsSchema,
			domains: Type.Optional(
				Type.String({ description: "Comma-separated domain whitelist, e.g. 'docs.python.org,github.com'" }),
			),
			recency: Type.Optional(Recency),
		}),

		async execute(_toolCallId, params, signal, _onUpdate, ctx) {
			const query = params.query.trim();
			if (!query) throw new Error("glm_web_search: query must not be empty");
			const maxResults = Math.min(50, Math.max(1, params.maxResults ?? 10));
			const domains = params.domains?.trim() || undefined;
			const recency = params.recency || "noLimit";

			const key = cacheKeyFor(["glm", query, maxResults, domains, recency]);
			const cached = cacheGet(key);
			if (cached) {
				return {
					content: [{ type: "text", text: formatResults(cached.results) }],
					details: { results: cached.results, engine: "glm-mcp", cached: true },
				};
			}

			const apiKey = await resolveGlmKey(ctx);
			const results = await glmSearch(apiKey, { query, maxResults, domains, recency }, signal);
			cacheSet(key, results, "glm-mcp");
			return {
				content: [{ type: "text", text: formatResults(results) }],
				details: { results, engine: "glm-mcp", cached: false },
			};
		},

		renderResult(result: any, options: { expanded: boolean }, theme: any) {
			const text = result.content[0];
			const plain = text?.type === "text" ? text.text : "(no results)";
			if (options.expanded) {
				return new Markdown(plain, 0, 0, getMarkdownTheme());
			}
			const details = result.details as { results?: SearchResult[] } | undefined;
			const count = details?.results?.length ?? 0;
			const header =
				theme.fg("toolTitle", theme.bold("glm_web_search ")) + theme.fg("accent", `${count} results`);
			const preview = plain.split("\n").slice(0, 3).join("\n");
			return new Text(`${header}\n${theme.fg("toolOutput", preview)}`, 0, 0);
		},
	});
}
