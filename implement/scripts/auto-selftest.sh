#!/usr/bin/env bash
# shippEdd auto-loop selftest (AUTO-07, layer 1). Deterministic temp-repo
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
# on a fresh agent-branch generation. Prints one line per check; ends with
# SELFTEST PASSED/FAILED. Touches nothing outside its own $TMPDIR sandbox.
#
# Usage: auto-selftest.sh   (run from anywhere; needs git + bash only)
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
skill_src="$(cd "$here/../.." && pwd)"            # the shippEdd skill tree
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
rm -f "$repo/.agents/skills/shippEdd/implement/scripts/auto-selftest.sh"  # never run the copy
for spec in 09-01:prod 09-02:prod 09-03:prod 09-04:prod 09-05:trunk 09-06:prod; do
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
wt="$(printf '%s\n' "$prompt" | grep -m1 -E '^  .*worktree$' | sed 's/^  //')"
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
mb="$(bash "$S/merge-back.sh" .planning 09 demo prod 2>&1)"; mbrc=$?; echo "$mb"
if [ "$mbrc" -eq 0 ] && printf '%s' "$mb" | grep -qF 'merged 09-demo/prod → prod' \
   && printf '%s' "$mb" | grep -qF 'branch agent/09-demo/prod deleted' \
   && ! git rev-parse --verify -q refs/heads/agent/09-demo/prod >/dev/null \
   && [ ! -d "$TMPDIR/shippEdd/09-demo/prod/worktree" ] \
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

echo
if [ "$fail" -eq 0 ]; then echo "SELFTEST PASSED ($pass checks)"; exit 0; fi
echo "SELFTEST FAILED ($fail failed, $pass passed)" >&2
exit 1
