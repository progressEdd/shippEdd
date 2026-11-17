/**
 * Shared types, cache, and formatting for the web-search extension.
 *
 * Result shape unifies DuckDuckGo (title/url/snippet) and GLM search-prime
 * (adds site/published) so tools, cache, and renderers share one format.
 */

export interface SearchResult {
	title: string;
	url: string;
	snippet: string;
	site: string;
	published: string;
}

export type Engine = "ddg" | "glm-mcp";

export interface CacheEntry {
	results: SearchResult[];
	cachedAt: number;
	engine: Engine;
}

const CACHE_TTL_MS = 5 * 60 * 1000;
const CACHE_MAX_ENTRIES = 50;

const cache = new Map<string, CacheEntry>();

export function cacheGet(key: string): CacheEntry | undefined {
	const entry = cache.get(key);
	if (!entry) return undefined;
	if (Date.now() - entry.cachedAt > CACHE_TTL_MS) {
		cache.delete(key);
		return undefined;
	}
	return entry;
}

export function cacheSet(key: string, results: SearchResult[], engine: Engine): void {
	while (cache.size >= CACHE_MAX_ENTRIES) {
		const oldest = cache.keys().next().value;
		if (oldest === undefined) break;
		cache.delete(oldest);
	}
	cache.set(key, { results, cachedAt: Date.now(), engine });
}

export function cacheKeyFor(parts: unknown[]): string {
	return JSON.stringify(parts);
}

export function formatResults(results: SearchResult[]): string {
	if (results.length === 0) return "No results found.";
	const encodeUrl = (url: string) =>
		url.replace(/[()]/g, (c) => "%" + c.charCodeAt(0).toString(16).toUpperCase());
	return results
		.map((r, i) => {
			const parts = [`${i + 1}. [${r.title || r.url}](${encodeUrl(r.url)})`];
			if (r.site) parts.push(`— ${r.site}${r.published ? ` (${r.published})` : ""}`);
			if (r.snippet) parts.push(`   ${r.snippet}`);
			return parts.join(" ");
		})
		.join("\n");
}
