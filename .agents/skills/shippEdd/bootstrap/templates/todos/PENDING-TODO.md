---
name: <slug>
captured: <YYYY-MM-DD>
what: "<the stray work, one line>"
severity: <low | medium | high>
context: "<one line so future-you understands without re-deriving>"
files:
  - <file/path it touches — optional :line or :start-end suffix>
---

## Problem

<why it matters / what's broken or missing — from the note or its conversation; `not stated` when nothing says>

## Solution

<the shape of the fix as currently imagined — short list or paragraph; `not stated` when unknown>

## Research

<findings already in hand from the conversation that produced this todo — paths, commands, verified facts, source links; `none` when it came with none>

## Decisions

<choices already settled in that conversation, one per line, that a future session must not reopen; `none` when nothing was settled>

<!--
/skill:todo copies this template to todos/pending/<NN-slug>.md, filling the
frontmatter (files list last) and whichever of the four sections the
conversation already carries — never inventing content; absent sections keep
their placeholder. Promote accumulated todos into a real phase via
/skill:todo --promote.
-->
