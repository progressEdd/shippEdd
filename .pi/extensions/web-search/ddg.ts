/**
 * ddg.ts — DuckDuckGo engine via the ddgs Python library
 *
 * Adapted from SchneiderDaniel/cheasee-pi web-search extension (MIT):
 * per-call isolated temp dirs, SEARCH_OK/SEARCH_DONE delimited output,
 * SIGTERM handling, concurrency semaphore.
 *
 * Simplified vs. upstream:
 * - venv lives in ~/.cache/pi-web-search/venv (outside any repo), created in
 *   a unique staging dir and moved into place with an atomic rename, so no
 *   cross-process lockfile dependency is needed. Concurrent creators race
 *   harmlessly: each builds a complete venv, rename() wins once, losers
 *   discard their staging copy and use the winner.
 * - temp run dirs use os.tmpdir() instead of a repo-local ignore/ dir.
 *
 * Requirements: python3 on PATH (first call bootstraps venv + ddgs).
 */

import { exec } from "node:child_process";
import fs from "node:fs";
import { homedir } from "node:os";
import os from "node:os";
import path from "node:path";
import { promisify } from "node:util";
import type { SearchResult } from "./types.ts";

const execAsync = promisify(exec);

const VENV_ROOT = path.join(homedir(), ".cache", "pi-web-search");
const VENV_DIR = path.join(VENV_ROOT, "venv");

const MAX_CONCURRENT = 5;
let active = 0;

async function acquire(signal?: AbortSignal): Promise<void> {
	while (active >= MAX_CONCURRENT) {
		signal?.throwIfAborted();
		await new Promise((r) => setTimeout(r, 200));
	}
	active++;
}
function release(): void {
	active = Math.max(0, active - 1);
}

export interface ExecResultLike {
	code: number;
	stdout: string;
	stderr: string;
}

function run(
	command: string,
	options: { timeout: number; signal?: AbortSignal },
): Promise<ExecResultLike> {
	return new Promise((resolve) => {
		exec(command, { timeout: options.timeout, signal: options.signal }, (err, stdout, stderr) => {
			if (err && typeof (err as any).killed !== "undefined" && (err as any).killed) {
				resolve({ code: 124, stdout: String(stdout ?? ""), stderr: "timeout" });
				return;
			}
			resolve({
				code: err ? ((err as any).code as number) ?? 1 : 0,
				stdout: String(stdout ?? ""),
				stderr: String(stderr ?? ""),
			});
		});
	});
}

/** Inline ddgs search script (from cheasee-pi, MIT). */
const SEARCH_SCRIPT = `
import json
import sys
import signal

signal.signal(signal.SIGTERM, lambda signum, frame: sys.exit(130))

def main():
    with open(sys.argv[1]) as f:
        config = json.load(f)

    query = config["query"]
    max_results = config.get("max_results", 10)

    try:
        from ddgs import DDGS

        results = list(DDGS().text(query, max_results=max_results, backend="auto"))
        out = [{"title": r.get("title", ""), "url": r.get("href", ""), "snippet": r.get("body", "")} for r in results]

        print("SEARCH_OK")
        print(json.dumps({"ok": True, "results": out}))
        print("SEARCH_DONE")
    except Exception as e:
        print("SEARCH_OK")
        print(json.dumps({"ok": False, "error": str(e)}))
        print("SEARCH_DONE")

main()
`;

let venvPromise: Promise<string> | undefined;

/**
 * Resolve the venv python binary, creating the venv on first use.
 * Atomic-rename strategy makes concurrent setup safe without lockfiles.
 */
export function ensureVenv(onUpdate?: (msg: string) => void): Promise<string> {
	if (venvPromise) return venvPromise;
	venvPromise = (async () => {
		const venvPython = path.join(VENV_DIR, "bin", "python");
		if (fs.existsSync(venvPython)) {
			const verify = await run(`'${venvPython}' -c 'import ddgs'`, { timeout: 20_000 });
			if (verify.code === 0) return venvPython;
		}

		onUpdate?.("First web_search call: creating Python environment (~30-60s)…");
		fs.mkdirSync(VENV_ROOT, { recursive: true });
		const staging = fs.mkdtempSync(path.join(VENV_ROOT, "stage-"));
		const stagingPython = path.join(staging, "bin", "python");
		try {
			const create = await run(`python3 -m venv '${staging}'`, { timeout: 120_000 });
			if (create.code !== 0) throw new Error(`venv create failed: ${create.stderr.slice(0, 300)}`);
			// ddgs>=0.8; idna>=3.15 pinned per PYSEC-2026-215 (see cheasee-pi)
			const install = await run(
				`'${stagingPython}' -m pip install --quiet 'ddgs>=0.8' 'idna>=3.15'`,
				{ timeout: 300_000 },
			);
			if (install.code !== 0) throw new Error(`pip install failed: ${install.stderr.slice(0, 300)}`);
			const verify = await run(`'${stagingPython}' -c 'import ddgs'`, { timeout: 20_000 });
			if (verify.code !== 0) throw new Error("ddgs import verification failed");

			try {
				fs.renameSync(staging, VENV_DIR);
			} catch {
				// Another process won the race; use theirs, discard staging.
				fs.rmSync(staging, { recursive: true, force: true });
			}
			return venvPython;
		} catch (err) {
			fs.rmSync(staging, { recursive: true, force: true });
			venvPromise = undefined; // allow retry on next call
			throw err;
		}
	})();
	return venvPromise;
}

/**
 * Run a DuckDuckGo search. Returns results, or throws an Error whose message
 * describes the failure (rate limits surface here as ddgs exceptions or as
 * empty result sets).
 */
export async function ddgSearch(
	query: string,
	maxResults: number,
	signal: AbortSignal | undefined,
	onUpdate?: (msg: string) => void,
): Promise<SearchResult[]> {
	await acquire(signal);
	try {
		const python = await ensureVenv(onUpdate);

		const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "pi-web-search-"));
		const configPath = path.join(tempDir, "config.json");
		const scriptPath = path.join(tempDir, "search.py");
		try {
			fs.writeFileSync(configPath, JSON.stringify({ query, max_results: maxResults }), "utf-8");
			fs.writeFileSync(scriptPath, SEARCH_SCRIPT, "utf-8");
			const result = await run(`'${python}' '${scriptPath}' '${configPath}'`, {
				timeout: 30_000,
				signal,
			});
			if (result.code !== 0) {
				throw new Error(`ddg script failed (code ${result.code}): ${result.stderr.slice(0, 300)}`);
			}
			const okIdx = result.stdout.indexOf("SEARCH_OK");
			const doneIdx = result.stdout.indexOf("SEARCH_DONE");
			if (okIdx === -1 || doneIdx === -1 || doneIdx <= okIdx) {
				throw new Error("ddg script produced no delimited output");
			}
			const payload = JSON.parse(
				result.stdout.slice(okIdx + "SEARCH_OK".length, doneIdx).trim(),
			) as { ok: boolean; results?: Array<{ title: string; url: string; snippet: string }>; error?: string };
			if (!payload.ok) throw new Error(`ddgs error: ${payload.error ?? "unknown"}`);
			return (payload.results ?? []).map((r) => ({
				title: r.title ?? "",
				url: r.url ?? "",
				snippet: r.snippet ?? "",
				site: "",
				published: "",
			}));
		} finally {
			fs.rmSync(tempDir, { recursive: true, force: true });
		}
	} finally {
		release();
	}
}
