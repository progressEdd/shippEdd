---
name: todo
description: Park stray work mid-flow without derailing — a note plus any research already sitting in the conversation becomes a numbered todo under todos/pending/ (frontmatter + problem/solution/research/decisions). Every capture closes with one offer to start planning it as a phase right away; or promote a batch of parked todos into a real roadmap phase in one shot (folder, roadmap entry, seeded context, todos moved to done). Run /skill:todo <note> anytime, or /skill:todo --promote when the todos pile up.
disable-model-invocation: true
---

# shippEdd todo — bank it, keep moving

You are the intake valve of the phase loop. Work is flowing — a plan is being grilled, a wave is running — and something stray surfaces: a bug spotted, an idea worth keeping, a "we should really…", often with research and half-made decisions already sitting in the conversation. Your job is to make all of it durable in one file and get out of the way. You never dispatch subagents, never touch a live phase, and never ask a battery of questions: intake that interrupts is intake that stops happening.

`<state>` is the workflow state dir resolved in step 0; all other paths are relative to it or to the repo root. This skill is self-contained: it resolves state through the suite's shared script `.agents/skills/shippEdd/scripts/state-dir.sh` (repo-relative); its templates come from the skill's own `bootstrap/templates/`.

## Ground rules

1. **Intake never blocks** — mode A asks at most **one** clarifying question, and only when the note names nothing actionable. Slug, area, and severity are always inferred or defaulted silently — never questions. The step-5 phase-plan offer is the one standing exception, and it fires only after the todo is safely on disk — a question that cannot lose the capture cannot block it. A parked idea is not worth an interrogation.
2. **Promote never edits an existing phase** — it appends exactly one new phase: new ROADMAP rows, one new folder, todos moved out of pending. Live phases, their artifacts, and ROADMAP history are not touched; STATE.md is updated only when it points at nothing.
3. **Plain files are the state** — a todo's presence in `todos/pending/` is the truth; its move to `todos/done/` is the record. No session memory anywhere: every mode re-reads the dir.
4. **Copy, don't generate** — todos come from the PENDING-TODO template, phase scaffolds from the skill's `bootstrap/templates/`, with placeholders filled. Capture never invents structure, and never invents content: the Problem/Solution/Research/Decisions sections record only what the conversation already established — an absent section keeps its placeholder.
5. **Recommend and stop** — the skill ends by naming the next command. Never run it yourself. One exception: an explicit **yes** to mode A's phase-plan offer hands off to promote + `/skill:define` — that yes is the invitation.

## Step 0 — resolve the state dir

Run `.agents/skills/shippEdd/scripts/state-dir.sh`. It prints exactly one line: the state dir path relative to the repo root (`$PLANNING_DIR` env → `.pi/planning.json` `state_dir` → `.planning`).

If that dir lacks both `STATE.md` and `ROADMAP.md`, no workflow state exists. Say:

> No workflow state found. Run `/skill:bootstrap` first — it creates the skeleton this skill reads.

Then stop.

## Step 0.5 — pick a mode

- **Arguments contain a note** (any free text, e.g. `/skill:todo fix the logout redirect loop`) → **Mode A — CAPTURE**.
- **Arguments say promote** (`--promote`, `promote`) → **Mode B — PROMOTE**.
- **No arguments** → check `<state>/todos/pending/`: files present → **Mode B**; empty → ask one plain line — "What should I capture?" — then run **Mode A** with the answer. (That question is the mode-A clarifying question; you get no second one.)

## Mode A — CAPTURE (the default)

Zero ceremony: infer everything you can from the note and the conversation around it, write one file, say one line, offer the phase once.

**1. Understand the note.** The note may lean on the conversation that produced it ("capture: that redirect bug") — resolve references yourself from context; that resolution is a fact, not a question. Only if nothing actionable can be inferred at all, ask exactly one question, in the grilling format (identical to bootstrap's, define's, implement's, review's):

```
❓ I can't tell what "<the note>" should record — what's the work?
  ➡️ 1. <your best inference from the conversation, one line>
    2. free text — say it in your words
```

**2. Infer the fields** — silently, defaults over questions:

- **Slug** — kebab-case from the note's subject, ≤ 4 words (`logout-redirect-loop`). One slug per todo, derived fresh.
- **Area** — from named paths, modules, or vocabulary in the note (`auth`, `ui`, `build`, `docs`, …). Default `general`.
- **Severity** — `high` when the words say pain (broken, crash, fails, urgent, security, data loss); `medium` for should-haves; default `low`. A parked idea is low until it says otherwise.
- **Files** — every path the note or its conversation names, listed verbatim with an optional `:line` or `:start-end` suffix (`api/routers/llm.py:231-234`); they land in the `files` list, the **last** key of the frontmatter. No path named → `files: none`.
- **NN** — next todo number: one more than the highest `NN-*` filename across `todos/pending/` **and** `todos/done/` (both — promoted todos move to done/ and keep their numbers forever, same law as shipped phases), zero-padded to two digits. Start at 01 when both are empty.

**3. Write the todo.** Copy the template — source `.agents/skills/shippEdd/bootstrap/templates/todos/PENDING-TODO.md` (the skill's own templates; there is no state-dir copy). If it is missing, stop and recommend rerunning `/skill:bootstrap` (it repairs the skill folder's templates without touching existing content). Write it as `<state>/todos/pending/<NN>-<slug>.md`. Fill the frontmatter: `name` = slug, `captured` = today's date, `what` = the note (one line), `severity` = the inferred severity, `context` = one line a future session could act on without re-deriving anything, and `files` **last** — one list item per named path with its optional `:line`/`:start-end` suffix, `files: none` when no path is named. Then fill the four body sections **from the conversation that produced the note — never invented**: **Problem** (why it matters / what's broken or missing), **Solution** (the fix as currently imagined), **Research** (findings already in hand — paths, commands, verified facts, source links; banked research is why this section exists), **Decisions** (choices already settled that a future session must not reopen, one per line). A section with nothing behind it keeps its template placeholder (`not stated` / `none`) — an honest empty beats a fabricated full. Drop the template's HTML comment.

**4. Reply in exactly one line:**

```
captured → todos/pending/<NN>-<slug>.md (<area>, <severity>)
```

**5. Phase-plan offer — the standing close of every capture.** After the receipt line, ask exactly one question:

```
❓ Start planning this as a phase now?
  ➡️ 1. not yet — it stays banked in todos/pending/ (promote later: /skill:todo --promote)
    2. yes — promote this todo into a phase and open /skill:define
```

- **No, or anything that isn't a yes** → stop. No follow-up, no hints, nothing else — the user was mid-flow; give them their flow back.
- **Yes** → run mode B with this todo as the only selection — skip mode B's listing and its multi-select question (the user just answered it), run steps 3–5 — then, instead of recommending `/skill:define`, execute the define flow on the new phase (rule 5's one exception: that yes is the invitation). The todo's Research and Decisions ride along via the CONTEXT seeding (mode B step 4.4).

## Mode B — PROMOTE (the batch graduation)

Mode B is reached three ways: a `--promote` argument, a bare invocation with todos pending, or mode A's phase-plan handoff. On the handoff path the selection is already made — skip steps 1–2 and run steps 3–5 on that single todo.

**1. List the pending todos** — read every file in `<state>/todos/pending/`, one line each:

```
Todos pending (3):
  01  fix logout redirect loop        auth    medium
  02  search results drop filters     search  high
  03  typo in README install steps    docs    low
```

(id, name, area, severity — plus What, Context, or Research when they add anything.)

**If none exist:** say `nothing to promote — todos/pending/ is empty`, then recommend: `/skill:define` if the roadmap has any phase (it continues or mints the next one), or `/skill:bootstrap` if the roadmap itself is still a blank skeleton. Stop.

**2. One multi-select question** (the only question promote asks):

```
❓ Promote which todos into a new phase? (multi-select — answer with ids)
  ➡️ 1. 02 — the high-severity one(s): <ids of every high todo>
    2. all of them: 01, 02, 03
    3. other — name the ids
```

The recommendation is the high-severity subset; if no todo is high, recommend all of them (they parked together for a reason).

**3. Derive the phase** from the selected todos: one **slug** (kebab, ≤ 3 words — the shared area or the dominant subject; when the todos share no thread, the first selected todo's slug carries), a one-line **goal** ("deliver the N promoted todos: <titles>"), and — per selected todo — one success criterion (its `what` field). You show the slug in the receipt, not in a question: promote asked its one question already.

**4. Execute the promote — one breath, in order:**

1. **NN** — one more than the highest `NN-*` phase number across `phases/` (shipped phases stay flat and keep their numbers forever, so a repo that shipped 01 and is mid-02 gets 03).
2. **ROADMAP** — append, never edit history:
   - `## Phases`: `- [ ] **Phase <NN>: <slug>** — <goal>`
   - `## Phase details`: a `### Phase <NN>: <slug>` block — Goal (from step 3), Depends on: `nothing` (unless the todos say otherwise), Requirements: `none recorded — promoted from todos`, success criteria = one per selected todo, and `Plans:` left as `- [ ] (filled by /skill:define)`
   - `## Progress`: a row `| <NN> `<slug>` | 0/0 | Not started | — |`
   - `## Next up`: point it at the new phase **only if no other unchecked phase precedes it** — a live phase keeps the focus (rule 2). If the roadmap was complete, the new phase is next up by right.
3. **Scaffold** `<state>/phases/<NN>-<slug>/` — same lazy rule `define` uses: create the folder and copy only `NN-CONTEXT.md` from `.agents/skills/shippEdd/bootstrap/templates/` (the skill's own templates), renaming `NN` → the real number in name and contents; missing template → stop, recommend `/skill:bootstrap`. Nothing else is pre-copied — every other phase artifact is written on demand by its producing agent.
4. **Seed `<NN>-CONTEXT.md`** — header: goal from step 3, today's date, `via /skill:todo promote` (the todos were banked mid-work, not grilled — say so). **Decisions table**: one row per selected todo, pre-settled — `| <n> | <todo title> | <todo What> | promoted todo <id> (<severity>), captured <date> |`. Constraints: `none — promoted todos`. Open questions: `none — frontier starts clear`. The phase enters planning with its history already decided. If a promoted todo carries a **Research** section beyond `none`, preserve it verbatim under a `## Banked research` heading at the bottom of its CONTEXT block — pre-decided input define reads, not new questions.
5. **Move the consumed todos** — `mkdir -p <state>/todos/done/` and `mv` each selected `todos/pending/<id>-<slug>.md` there, filename unchanged. Presence in pending/ was the truth; done/ is the record.
6. **STATE.md — only if it points at nothing** (rule 2): i.e. its body names no live phase (`<none yet…>`, or a phase that is shipped or absent). Then set frontmatter `next_action: /skill:define`, `progress: 0%`, body: the new phase and `promoted from <k> todos — awaiting planning`. If STATE.md names a live phase, leave it byte-for-byte untouched.

**5. Promote receipt:**

```
Phase <NN>-<slug> promoted
  todos     <ids> → todos/done/
  roadmap   Phase <NN> appended (unchecked) · Next up <unchanged: <live phase> | now <NN>-<slug>>
  folder    phases/<NN>-<slug>/ scaffolded · CONTEXT seeded with <k> todo row(s)
  state     <untouched — <live phase> still holds focus | → /skill:define>
Next: `/skill:define` — for <the first unchecked phase> (that's <NN>-<slug> itself, or the live phase it queued behind) — in a fresh session (clear this context first; everything durable is on disk).
```

Then stop (rule 5) — unless mode B ran as mode A's handoff, in which case the define flow begins immediately instead of being recommended. todo's whole contribution to flow control is that last line.
