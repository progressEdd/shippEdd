#!/usr/bin/env bash
# shippEdd cumulative selftest (AUTO-07 layer 1; DISP-06) — moved to the suite-root scripts/ home by phase 05.
# simulation of the sequential auto loop: mirrors this repo's worktree layout
# (orchestrator branch at the repo root, target branch in a sibling worktree,
# per-target agent worktrees under $TMPDIR), copies this skill tree into the
# sandbox, and drives the REAL dispatch-plan.sh / watch-wave.sh /
# merge-back.sh with scripted executors injected via SHIPPEDD_EXECUTOR_CMD.
# Cases: (1) sequential-topology refusal, (2) happy-path watch + worktree
# reuse, (3) fail-once bounded recovery via --fix-instructions, (4) attempt
# budget exhaustion (3 attempts, 4th refused), (5) clean per-target
# merge-back incl. the AUTO-01 branch delete + idempotent re-run,
# (6) DRIFT halt recovered within the merge budget, (7) merge-budget refusal
# on a fresh agent-branch generation. Phase 05 adds (8) dispatcher migration
# (shared dispatch, nothing under .planning/), (9) config-driven placement,
# (10) no-worktrees branch fallback, (11) PR receipt fallback, (12) PR create
# via fake gh (DISP-06). Prints one line per check; ends with
# SELFTEST PASSED/FAILED. Touches nothing outside its own $TMPDIR sandbox.
#
# Usage: auto-selftest.sh   (run from anywhere; needs git + bash only)
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
skill_src="$(cd "$here/.." && pwd)"               # the shippEdd skill tree (scripts/ sits at its root since phase 05)
tmp="$(mktemp -d -t shippEdd-auto-selftest.XXXXXX)"
export TMPDIR="$tmp/tmp"; mkdir -p "$TMPDIR"
cleanup() { rm -rf "$tmp"; }
trap cleanup EXIT

pass=0; fail=0
ok()  { pass=$((pass + 1)); echo "  ok: $1"; }
bad() { fail=$((fail + 1)); echo "FAIL: $1" >&2; }

repo="$tmp/repo"
git init -q "$repo"
git -C "$repo" config user.email selftest@shippEdd.invalid
git -C "$repo" config user.name "shippEdd selftest"
git -C "$repo" checkout -q -b trunk
git -C "$repo" commit -q --allow-empty -m init
mkdir -p "$repo/.planning/phases/09-demo" "$repo/.agents/skills"
cp -R "$skill_src" "$repo/.agents/skills/shippEdd"
rm -rf "$repo/.agents/skills/shippEdd/.git"   # vendored as plain files — a gitlink copy would read dirty
                                              # once auto-selftest.sh is tracked at the source
rm -f "$repo/.agents/skills/shippEdd/scripts/auto-selftest.sh"  # never run the copy
for spec in 09-01:prod 09-02:prod 09-03:prod 09-04:prod 09-05:trunk 09-06:prod 09-07:prod; do
  pid_="${spec%%:*}"; tgt_="${spec##*:}"
  printf -- '---\nwave: %s\ndepends_on: []\ntarget: %s\n---\n\n# Plan %s: selftest fixture\n' \
    "${pid_#*-}" "$tgt_" "$pid_" > "$repo/.planning/phases/09-demo/$pid_-PLAN.md"
done
git -C "$repo" add -A
git -C "$repo" commit -q -m "plans + vendored skill copy"
git -C "$repo" worktree add -q "$tmp/prod-wt" -b prod    # target branch in a SIBLING worktree
S="$repo/.agents/skills/shippEdd/implement/scripts"
cd "$repo"

# ---- scripted executor: reads the composed prompt on stdin, plays the role.
cat > "$tmp/fake-executor.sh" <<'EOF'
#!/usr/bin/env bash
set -u
prompt="$(cat)"
wt="$(printf '%s\n' "$prompt" | sed 's/^.* \(Your working tree:\)$/\1/' | sed -n '/^Your working tree:$/{n;p}' | sed 's/^  //')"   # deviation (05-05-D4): the prompt carries "Your working tree:" as a sentence tail, not a standalone line — normalize, then the plan's extractor
smry="$(printf '%s\n' "$prompt" | grep -m1 -E '^  .*SUMMARY\.md$' | sed 's/^  //')"
runmark="$(printf '%s\n' "$prompt" | grep -m1 -oE 'mv [^ ]+\.running [^ ]+\.done' | awk '{print $2}')"
attempt="$(printf '%s\n' "$prompt" | grep -m1 -oE 'attempt [0-9]+ of at most 3' | grep -oE '[0-9]+' | head -n1)"
id="$(basename "${smry%-SUMMARY.md}")"
failed="${runmark%.running}.failed"
if [ "${FAKE_MODE:-ok}" = "always-fail" ] \
   || { [ "${FAKE_MODE:-ok}" = "fail-once" ] && [ "$attempt" = "1" ]; }; then
  mv "$runmark" "$failed"
  printf 'synthetic failure (%s), plan %s, attempt %s\n' "${FAKE_MODE:-ok}" "$id" "${attempt:-?}" >> "$failed"
  exit 0
fi
[ "${FAKE_MODE:-ok}" = "slow-ok" ] && sleep 8
cd "$wt" || exit 1
echo "fake work $id" > "fake-$id.txt"
git add "fake-$id.txt" && git commit -q -m "chore($id): synthetic executor work"
mkdir -p "$(dirname "$smry")"
cat > "$smry" <<EOF2
---
status: complete
duration: 1m
key-files:
  created:
    - fake-$id.txt
  modified: []
requirements-completed: []
key-decisions: []
deviations: none
---

# $id SUMMARY (synthetic)

One synthetic commit on the per-target agent branch.
EOF2
mv "$runmark" "${runmark%.running}.done"
echo "## EXECUTION COMPLETE"
EOF
chmod +x "$tmp/fake-executor.sh"

disp() {  # disp <FAKE_MODE> <id> <target> [extra args...]
  local mode="$1" id="$2" tgt="$3"; shift 3
  FAKE_MODE="$mode" SHIPPEDD_EXECUTOR_CMD="$tmp/fake-executor.sh" \
    bash "$S/dispatch-plan.sh" "$id" ".planning/phases/09-demo/$id-PLAN.md" "$tgt" "$@"
}

echo "case 1 — sequential guard (AUTO-05)"
out1="$(disp slow-ok 09-01 prod)"; echo "$out1"
out2="$(disp ok 09-02 prod 2>&1)" ; rc2=$?
if [ "$rc2" -ne 0 ] && printf '%s' "$out2" | grep -qF 'REFUSED: plan 09-01 is still executing in the prod worktree (sequential topology)'; then
  ok "second live executor in the prod worktree refused"
else
  bad "expected REFUSED, got: $out2"
fi
w="$(bash "$S/watch-wave.sh" .planning 09 demo 09-01 2>&1)"; wrc=$?
if [ "$wrc" -eq 0 ] && printf '%s' "$w" | grep -qF 'resolved 09-01: executed (SUMMARY complete)'; then
  ok "watch resolves 09-01 executed (exit 0)"
else
  bad "watch 09-01 rc=$wrc out=$w"
fi

echo "case 2 — worktree reuse across plans of one target"
out="$(disp ok 09-02 prod)"; echo "$out"
if printf '%s' "$out" | grep -qF 'reused prod worktree (branch agent/09-demo/prod)'; then
  ok "09-02 reuses the per-target prod worktree"
else
  bad "expected worktree reuse, got: $out"
fi
w="$(bash "$S/watch-wave.sh" .planning 09 demo 09-02 2>&1)"; wrc=$?
[ "$wrc" -eq 0 ] && ok "watch resolves 09-02 executed" || bad "watch 09-02 rc=$wrc out=$w"

echo "case 3 — fail-once bounded recovery with --fix-instructions (AUTO-03)"
out="$(disp fail-once 09-03 prod)"; echo "$out"
w="$(bash "$S/watch-wave.sh" .planning 09 demo 09-03 2>&1)"; wrc=$?
if [ "$wrc" -eq 2 ] && printf '%s' "$w" | grep -qF 'resolved 09-03: failed — synthetic failure (fail-once)' \
   && printf '%s' "$w" | grep -qF '(attempt 1/3)'; then
  ok "first attempt fails, watch exits 2 with the reason and budget"
else
  bad "expected fail attempt 1/3 exit 2, rc=$wrc out=$w"
fi
fix="$TMPDIR/shippEdd/09-demo/09-03/fix-1.md"
printf 'Diagnosis: injected synthetic first-attempt failure.\nFix: run the plan again; the failure is synthetic. Verify fake-09-03.txt lands on the branch and the SUMMARY writes.\n' > "$fix"
out="$(disp fail-once 09-03 prod --force --fix-instructions "$fix")"; echo "$out"
w="$(bash "$S/watch-wave.sh" .planning 09 demo 09-03 2>&1)"; wrc=$?
if [ "$wrc" -eq 0 ] && printf '%s' "$w" | grep -qF 'resolved 09-03: executed (SUMMARY complete)'; then
  ok "recovery dispatch succeeds on attempt 2"
else
  bad "expected executed on attempt 2, rc=$wrc out=$w"
fi
n="$(wc -l < "$TMPDIR/shippEdd/09-demo/09-03/attempts" | tr -d '[:space:]')"
[ "$n" -eq 2 ] && ok "attempt ledger shows 2 dispatches" || bad "attempts file has $n lines, expected 2"

echo "case 4 — budget exhaustion: 3 attempts, 4th refused (AUTO-03)"
for n in 1 2 3; do
  if [ "$n" -eq 1 ]; then disp always-fail 09-04 prod >/dev/null; else disp always-fail 09-04 prod --force >/dev/null; fi
  w="$(bash "$S/watch-wave.sh" .planning 09 demo 09-04 2>&1)"; wrc=$?
  if [ "$n" -lt 3 ]; then
    [ "$wrc" -eq 2 ] && printf '%s' "$w" | grep -qF "(attempt $n/3)" \
      && ok "attempt $n fails, watch exits 2" || bad "attempt $n: rc=$wrc out=$w"
  else
    [ "$wrc" -eq 3 ] && printf '%s' "$w" | grep -qF 'BUDGET: plan 09-04 exhausted 3 attempts (2 retries) — stop the loop, hand the failure dossier to the human' \
      && ok "attempt 3 fails, watch exits 3 with the BUDGET stop line" || bad "attempt 3: rc=$wrc out=$w"
  fi
done
out="$(disp always-fail 09-04 prod --force 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -qF 'BUDGET: plan 09-04 already used 3 attempts (2 retries) — refusing dispatch'; then
  ok "the 4th dispatch is mechanically refused"
else
  bad "expected dispatch refusal, got: $out"
fi

echo "case 5 — clean per-target merge-back + AUTO-01 branch delete + idempotence"
# deviation (05-05-D0): cases 5–7 were written for auto-merge semantics; 05-02
# flipped the default disposition to pr, so they now hit the PR receipt fallback
# instead of merging. Pin the disposition these cases test; the pr default is
# restored before the phase-05 cases (below).
printf '{\n  "disposition": "auto-merge"\n}\n' > "$repo/.planning/config.json"
mb="$(bash "$S/merge-back.sh" .planning 09 demo prod 2>&1)"; mbrc=$?; echo "$mb"
if [ "$mbrc" -eq 0 ] && printf '%s' "$mb" | grep -qF 'merged 09-demo/prod → prod' \
   && printf '%s' "$mb" | grep -qF 'branch agent/09-demo/prod deleted' \
   && ! git rev-parse --verify -q refs/heads/agent/09-demo/prod >/dev/null \
   && [ ! -d "$tmp/agent/09-demo/prod" ] \
   && git -C "$tmp/prod-wt" log --merges --grep 'merge(09-demo/prod):' -1 --format=%H | grep -q .; then
  ok "per-target merge lands, worktree removed, branch deleted from the target checkout — no HALT (AUTO-01)"
else
  bad "merge-back prod failed: rc=$mbrc out=$mb"
fi
mb2="$(bash "$S/merge-back.sh" .planning 09 demo prod 2>&1)"; mb2rc=$?
[ "$mb2rc" -eq 0 ] && printf '%s' "$mb2" | grep -qF 'landed 09-demo/prod → prod (already merged — nothing to do)' \
  && ok "re-run is idempotent and burns no attempt" || bad "re-run: rc=$mb2rc out=$mb2"

echo "case 6 — DRIFT halt recovered within the merge budget (AUTO-04)"
out="$(disp ok 09-05 trunk)"; echo "$out"
w="$(bash "$S/watch-wave.sh" .planning 09 demo 09-05 2>&1)"; wrc=$?
[ "$wrc" -eq 0 ] && ok "watch resolves 09-05 executed (trunk target)" || bad "watch 09-05 rc=$wrc out=$w"
git add -A .planning && git commit -q -m "chore(09-demo): gate-side summary commits keep the trunk checkout clean"
printf '%s\n' "$(git rev-parse prod)" > "$TMPDIR/shippEdd/09-demo/trunk/fork-base"   # corrupt: not the merge-base
mb="$(bash "$S/merge-back.sh" .planning 09 demo trunk 2>&1)"; mbrc=$?
[ "$mbrc" -ne 0 ] && printf '%s' "$mb" | grep -qF 'DRIFT: agent/09-demo/trunk stranded' \
  && ok "corrupted fork base halts with the DRIFT handoff (attempt 1)" || bad "expected DRIFT, rc=$mbrc out=$mb"
git merge-base agent/09-demo/trunk trunk > "$TMPDIR/shippEdd/09-demo/trunk/fork-base"  # the halt's own recovery
mb="$(bash "$S/merge-back.sh" .planning 09 demo trunk 2>&1)"; mbrc=$?; echo "$mb"
[ "$mbrc" -eq 0 ] && printf '%s' "$mb" | grep -qF 'merged 09-demo/trunk → trunk' \
  && ok "recovery re-record + retry merges cleanly (attempt 2 of 3)" || bad "expected clean merge, rc=$mbrc out=$mb"
n="$(wc -l < "$TMPDIR/shippEdd/09-demo/trunk/merge-attempts" | tr -d '[:space:]')"
[ "$n" -eq 2 ] && ok "merge ledger shows 2 attempts" || bad "merge-attempts has $n lines, expected 2"

echo "case 7 — merge-budget refusal on a fresh generation (AUTO-04)"
out="$(disp ok 09-06 prod)"; echo "$out"
w="$(bash "$S/watch-wave.sh" .planning 09 demo 09-06 2>&1)"; wrc=$?
[ "$wrc" -eq 0 ] && ok "watch resolves 09-06 executed (fresh prod generation)" || bad "watch 09-06 rc=$wrc out=$w"
printf '%s\n' "$(git rev-parse trunk)" > "$TMPDIR/shippEdd/09-demo/prod/fork-base"   # not prod's merge-base
for n in 1 2 3; do
  mb="$(bash "$S/merge-back.sh" .planning 09 demo prod 2>&1)"; rc=$?
  [ "$rc" -ne 0 ] && printf '%s' "$mb" | grep -qF 'DRIFT: agent/09-demo/prod stranded' \
    && ok "drift attempt $n halts (budget $n/3)" || bad "drift attempt $n: rc=$rc out=$mb"
done
mb="$(bash "$S/merge-back.sh" .planning 09 demo prod 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && printf '%s' "$mb" | grep -qF 'BUDGET: merge of agent/09-demo/prod at 3 attempts (2 retries) — refusing' \
  && ok "the 4th merge attempt is mechanically refused" || bad "expected merge BUDGET refusal, got: $mb"

rm -f "$repo/.planning/config.json"   # deviation (05-05-D0): restore the pr default for the phase-05 cases

echo "case 8 — dispatcher migration: shared dispatch, nothing under .planning/ (DISP-01/02)"
H="$TMPDIR/shippEdd"                                   # the sandbox runs home (absent config → tmp)
mkdir -p "$H/09-demo"
printf 'researcher prompt stub — flip your marker when done\n' > "$H/09-demo/09-research.prompt.md"
cat > "$tmp/research-fake.sh" <<EOF
#!/usr/bin/env bash
cat >/dev/null   # drain the prompt
mv "$H/09-demo/09-research.running" "$H/09-demo/09-research.done"
echo "## RESEARCH COMPLETE (synthetic)"
EOF
chmod +x "$tmp/research-fake.sh"
run_out="$(FAKE_MODE=ok SHIPPEDD_EXECUTOR_CMD="$tmp/research-fake.sh" \
  bash "$repo/.agents/skills/shippEdd/scripts/dispatch.sh" 09-research "$H/09-demo/09-research.prompt.md" --state-dir "$H/09-demo")"
echo "$run_out"
if printf '%s' "$run_out" | grep -qF 'dispatched 09-research' \
   && [ -f "$H/09-demo/09-research.done" ] && [ -f "$H/09-demo/09-research.log" ] \
   && [ ! -e "$repo/.planning/runs" ]; then
  ok "shared dispatch lands markers/log under the runs home; .planning/ stays runs-free"
else
  bad "migration dispatch misplaced state: out=$run_out"
fi
[ -e "$repo/.planning/runs" ] && bad ".planning/runs exists after shared dispatch (DISP-02 violation)"
# deviation (05-05-D3): grep -q exits at first match → dispatch.sh takes SIGPIPE mid-list →
# pipefail fails the pipeline even though grep matched. Capture first, then grep.
st="$(bash "$repo/.agents/skills/shippEdd/scripts/dispatch.sh" --status --state-dir "$H/09-demo")"
printf '%s' "$st" | grep -qF '09-research' \
  && ok "--status lists the shared-dispatch run" || bad "--status missed 09-research (st=$st)"

echo "case 9 — config placement: runs.dir relocates markers + worktrees"
printf '{\n  "runs": { "dir": "wt-home" }\n}\n' > "$repo/.planning/config.json"
out="$(disp ok 09-02 prod --force)"; echo "$out"    # re-dispatch a finished plan into the new home
if printf '%s' "$out" | grep -qF 'dispatched 09-02' \
   && [ -d "$repo/wt-home/09-demo/09-02" ]; then
  ok "markers under wt-home/09-demo/ (config-driven home)"
else
  bad "config placement wrong: out=$out"
fi
if [ -d "$repo/wt-home/agent/09-demo/prod" ] \
   || git worktree list --porcelain | grep -q "refs/heads/agent/09-demo/prod"; then
  ok "the agent branch's worktree is placed per config (or reused at its existing checkout)"
else
  bad "no worktree found for the prod agent branch under either base"
fi
w="$(bash "$S/watch-wave.sh" .planning 09 demo 09-02 2>&1)"; wrc=$?
[ "$wrc" -eq 0 ] && printf '%s' "$w" | grep -qF 'resolved 09-02: executed (SUMMARY complete)' \
  && ok "watch-wave reads the config-driven home (SUMMARY oracle)" || bad "watch 09-02 rc=$wrc out=$w"
rm -f "$repo/.planning/config.json"   # restore defaults for cases 10–12
ok "config restored (absent = defaults)"

echo "case 10 — no-worktrees fallback: branch mode in the main checkout (DISP-04)"
repo2="$tmp/repo2"
git init -q "$repo2"
git -C "$repo2" config user.email selftest@shippEdd.invalid
git -C "$repo2" config user.name "shippEdd selftest"
git -C "$repo2" checkout -q -b main
git -C "$repo2" commit -q --allow-empty -m init
mkdir -p "$repo2/.planning/phases/10-demo" "$repo2/.agents/skills"
cp -R "$skill_src" "$repo2/.agents/skills/shippEdd"
rm -rf "$repo2/.agents/skills/shippEdd/.git"
rm -f "$repo2/.agents/skills/shippEdd/scripts/auto-selftest.sh"
printf -- '---\nwave: 1\ndepends_on: []\ntarget: main\n---\n\n# Plan 10-01: branch-mode fixture\n' \
  > "$repo2/.planning/phases/10-demo/10-01-PLAN.md"
# deviation (05-05-D5): write the disposition config with the fixture (committed) —
# the plan placed it after the fixture commit, leaving it untracked for branch-mode
# merge-back, whose dirt filter tolerates only .planning/phases/ artifacts.
printf '{\n  "disposition": "auto-merge"\n}\n' > "$repo2/.planning/config.json"
git -C "$repo2" add -A && git -C "$repo2" commit -q -m "fixture"
S2="$repo2/.agents/skills/shippEdd/implement/scripts"
mode2="$(cd "$repo2" && bash "$repo2/.agents/skills/shippEdd/scripts/runs-dir.sh" mode)"
[ "$mode2" = branch ] && ok "worktree-less repo auto-detects branch mode" || bad "mode2=$mode2, expected branch"
b_out="$(cd "$repo2" && FAKE_MODE=ok SHIPPEDD_EXECUTOR_CMD="$tmp/fake-executor.sh" \
  bash "$S2/dispatch-plan.sh" 10-01 .planning/phases/10-demo/10-01-PLAN.md main)"
echo "$b_out"
if printf '%s' "$b_out" | grep -qF "worktree $repo2 (main checkout, branch mode)" \
   && [ "$(git -C "$repo2" branch --show-current)" = "agent/10-demo/main" ]; then
  ok "branch mode: main checkout switched onto the agent branch, no worktree created"
else
  bad "branch dispatch wrong: out=$b_out current=$(git -C "$repo2" branch --show-current)"
fi
w="$(cd "$repo2" && bash "$S2/watch-wave.sh" .planning 10 demo 10-01 2>&1)"; wrc=$?
[ "$wrc" -eq 0 ] && ok "watch resolves 10-01 in branch mode" || bad "watch 10-01 rc=$wrc out=$w"
mb="$(cd "$repo2" && bash "$S2/merge-back.sh" .planning 10 demo main 2>&1)"; mbrc=$?; echo "$mb"
if [ "$mbrc" -eq 0 ] && printf '%s' "$mb" | grep -qF 'merged 10-demo/main → main' \
   && [ "$(git -C "$repo2" branch --show-current)" = main ] \
   && ! git -C "$repo2" rev-parse --verify -q refs/heads/agent/10-demo/main >/dev/null \
   && git -C "$repo2" log main --merges --grep 'merge(10-demo/main):' -1 --format=%H | grep -q .; then
  ok "branch-mode merge-back: checkout back on main, agent branch deleted, merge landed"
else
  bad "branch merge-back failed: rc=$mbrc out=$mb cur=$(git -C "$repo2" branch --show-current)"
fi

echo "case 11 — PR receipt fallback: no remote, the run never fails (DISP-05)"
# deviation (05-05-D1): case 7's strand survives (merge budget exhausted, fork
# base corrupted by the DRIFT drill); the PR-fallback case presumes a fresh
# generation — remove the synthetic strand so the dispatch below forks anew.
git worktree remove "$tmp/agent/09-demo/prod"
git branch -D agent/09-demo/prod
out="$(disp ok 09-07 prod)"; echo "$out"
w="$(bash "$S/watch-wave.sh" .planning 09 demo 09-07 2>&1)"; wrc=$?
[ "$wrc" -eq 0 ] && ok "watch resolves 09-07 executed" || bad "watch 09-07 rc=$wrc out=$w"
# deviation (05-05-D2): case 5 legitimately landed a merge(09-demo/prod) commit
# on prod — assert "this run merges nothing NEW", not "prod never merged".
m0="$(git log prod --merges --grep 'merge(09-demo/prod):' --format=%H | wc -l)"
mb="$(bash "$S/merge-back.sh" .planning 09 demo prod 2>&1)"; mbrc=$?
m1="$(git log prod --merges --grep 'merge(09-demo/prod):' --format=%H | wc -l)"
if [ "$mbrc" -eq 0 ] && printf '%s' "$mb" | grep -qF 'PR unavailable:' \
   && printf '%s' "$mb" | grep -qF 'branch agent/09-demo/prod stays' \
   && printf '%s' "$mb" | grep -qF '"disposition": "auto-merge"' \
   && git rev-parse --verify -q refs/heads/agent/09-demo/prod >/dev/null \
   && [ "$m1" -eq "$m0" ]; then
  ok "receipt fallback: exit 0, branch stays, nothing merged, options named"
else
  bad "PR fallback wrong: rc=$mbrc out=$mb"
fi

echo "case 12 — PR create: push + gh pr create, branch kept, worktree removed"
git init -q --bare "$tmp/remote.git"
git remote add origin "$tmp/remote.git"
mkdir -p "$tmp/bin"
cat > "$tmp/bin/gh" <<'EOF'
#!/usr/bin/env bash
echo "gh $*" >> "$GH_CALLS"
case "$1 $2" in
  "pr create") echo "https://github.com/example/shippEdd/pull/1" ;;
  *) exit 0 ;;
esac
EOF
chmod +x "$tmp/bin/gh"
: > "$tmp/gh-calls"
m0="$(git log prod --merges --grep 'merge(09-demo/prod):' --format=%H | wc -l)"   # deviation (05-05-D2): no NEW merge, see case 11
mb="$(PATH="$tmp/bin:$PATH" GH_CALLS="$tmp/gh-calls" bash "$S/merge-back.sh" .planning 09 demo prod 2>&1)"; mbrc=$?
m1="$(git log prod --merges --grep 'merge(09-demo/prod):' --format=%H | wc -l)"
if [ "$mbrc" -eq 0 ] && printf '%s' "$mb" | grep -qF 'PR https://github.com/example/shippEdd/pull/1' \
   && printf '%s' "$mb" | grep -qF 'branch kept (PR head)' \
   && grep -qF 'pr create --base prod --head agent/09-demo/prod' "$tmp/gh-calls" \
   && git --git-dir="$tmp/remote.git" rev-parse --verify -q refs/heads/agent/09-demo/prod >/dev/null \
   && git rev-parse --verify -q refs/heads/agent/09-demo/prod >/dev/null \
   && ! git worktree list --porcelain | grep -q "refs/heads/agent/09-demo/prod" \
   && [ "$m1" -eq "$m0" ]; then
  ok "PR flow: branch pushed to remote, PR created, worktree removed, branch kept, no local merge"
else
  bad "PR flow wrong: rc=$mbrc out=$mb calls=$(cat "$tmp/gh-calls" 2>/dev/null)"
fi

echo
if [ "$fail" -eq 0 ]; then echo "SELFTEST PASSED ($pass checks)"; exit 0; fi
echo "SELFTEST FAILED ($fail failed, $pass passed)" >&2
exit 1
