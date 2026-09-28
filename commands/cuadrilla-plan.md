---
description: Cuadrilla — analyze a request and produce a delegation plan without changing anything
agent: cuadrilla
---

PLANNING MODE — do not delegate any task that edits files, runs builds, or touches git. You may use `explore` and `cuadrilla-architect` for read-only analysis.

Request:
$ARGUMENTS

Current repository state:
!`git status --short 2>/dev/null | head -50`

Produce:
1. **Triage** — tier (T0–T3) and why.
2. **What I found** — relevant stack, files and existing patterns (ground this in the actual code).
3. **Open questions** — only the ones that change the plan, each with your recommended default.
4. **Plan** — ordered steps; for each: owner agent, goal, key files, dependencies, and whether it can run in parallel.
5. **Risks** — what could go wrong and how the plan mitigates it.
6. **Out of scope** — what you deliberately left out.

End by asking whether to execute the plan as-is or with changes.
