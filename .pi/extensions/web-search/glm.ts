/**
 * glm.ts — GLM Web Search MCP engine (z.ai search-prime)
 *
 * Calls z.ai's Web Search MCP Server (included with the GLM Coding Plan)
 * directly over Streamable HTTP: initialize → notifications/initialized →
 * tools/call web_search_prime. Hand-rolled JSON-RPC, no MCP SDK dependency.
 * The MCP session id is cached in-module and re-initialized on expiry.
 *
 * Response quirk: content[0].text is a JSON-encoded string containing the
 * result array (double-encoded), parsed defensively below.
 *
 * Docs: https://docs.z.ai/devpack/mcp/search-mcp-server
 */

import type { SearchResult } from "./types.ts";

const MCP_ENDPOINT = "https://api.z.ai/api/mcp/web_search_prime/mcp";

export interface GlmSearchParams {
	query: string;
	domains?: string;
	recency?: string;
	maxResults?: number;
}

let mcpSessionId: string | undefined;
let rpcId = 0;

async function parseRpcResponse(res: Response): Promise<any> {
	const text = await res.text();
	if (text.includes("data:")) {
		const data = text
			.split("\n")
			.filter((l) => l.startsWith("data:"))
			.map((l) => l.slice(5).trim())
			.join("");
		return data ? JSON.parse(data) : undefined;
	}
	return text ? JSON.parse(text) : undefined;
}

function baseHeaders(apiKey: string): Record<string, string> {
	const headers: Record<string, string> = {
		Authorization: `Bearer ${apiKey}`,
		"Content-Type": "application/json",
		Accept: "application/json, text/event-stream",
	};
	if (mcpSessionId) headers["Mcp-Session-Id"] = mcpSessionId;
	return headers;
}

async function mcpFetch(
	apiKey: string,
	body: Record<string, unknown>,
	signal: AbortSignal | undefined,
): Promise<Response> {
	return fetch(MCP_ENDPOINT, {
		method: "POST",
		headers: baseHeaders(apiKey),
		body: JSON.stringify(body),
		signal,
	});
}

/** Ensure an initialized MCP session (cached). */
async function ensureSession(apiKey: string, signal: AbortSignal | undefined): Promise<void> {
	if (mcpSessionId) return;
	const res = await mcpFetch(
		apiKey,
		{
			jsonrpc: "2.0",
			id: ++rpcId,
			method: "initialize",
			params: {
				protocolVersion: "2025-03-26",
				capabilities: {},
				clientInfo: { name: "pi-web-search", version: "1.0.0" },
			},
		},
		signal,
	);
	if (!res.ok) throw new Error(`GLM search: MCP initialize failed: HTTP ${res.status}`);
	mcpSessionId = res.headers.get("mcp-session-id") ?? undefined;
	await parseRpcResponse(res);
	await mcpFetch(apiKey, { jsonrpc: "2.0", method: "notifications/initialized" }, signal).then((r) =>
		r.text(),
	);
}

interface RawResult {
	title?: unknown;
	link?: unknown;
	content?: unknown;
	media?: unknown;
	publish_date?: unknown;
}

/**
 * Run a web_search_prime call. Returns mapped results (untrimmed).
 * Throws on HTTP, JSON-RPC, or tool-level errors.
 */
export async function glmSearch(
	apiKey: string,
	params: GlmSearchParams,
	signal: AbortSignal | undefined,
): Promise<SearchResult[]> {
	await ensureSession(apiKey, signal);

	const args: Record<string, unknown> = { search_query: params.query };
	if (params.domains) args.search_domain_filter = params.domains;
	if (params.recency && params.recency !== "noLimit") args.search_recency_filter = params.recency;

	let res = await mcpFetch(
		apiKey,
		{ jsonrpc: "2.0", id: ++rpcId, method: "tools/call", params: { name: "web_search_prime", arguments: args } },
		signal,
	);

	// Session may have expired server-side: re-initialize once and retry.
	if ((res.status === 404 || res.status === 400) && mcpSessionId) {
		mcpSessionId = undefined;
		await ensureSession(apiKey, signal);
		res = await mcpFetch(
			apiKey,
			{ jsonrpc: "2.0", id: ++rpcId, method: "tools/call", params: { name: "web_search_prime", arguments: args } },
			signal,
		);
	}

	if (!res.ok) throw new Error(`GLM search: MCP tools/call failed: HTTP ${res.status}`);
	const rpc = await parseRpcResponse(res);
	if (rpc?.error) throw new Error(`GLM search: MCP error ${rpc.error.code}: ${rpc.error.message}`);
	if (rpc?.result?.isError) {
		const detail = rpc.result.content?.find((c: any) => c.type === "text")?.text ?? "unknown error";
		throw new Error(`GLM search: ${String(detail).slice(0, 300)}`);
	}

	const textPart = (rpc?.result?.content ?? []).find((c: any) => c.type === "text")?.text;
	if (typeof textPart !== "string") throw new Error("GLM search: unexpected MCP response shape");
	let parsed: unknown = textPart;
	for (let i = 0; i < 2 && typeof parsed === "string"; i++) {
		try {
			parsed = JSON.parse(parsed as string);
		} catch {
			break;
		}
	}
	if (!Array.isArray(parsed)) throw new Error("GLM search: could not parse search results");

	const max = params.maxResults ?? 10;
	return (parsed as RawResult[]).slice(0, max).map((r) => ({
		title: String(r.title ?? ""),
		url: String(r.link ?? ""),
		snippet: String(r.content ?? ""),
		site: String(r.media ?? ""),
		published: String(r.publish_date ?? ""),
	}));
}
