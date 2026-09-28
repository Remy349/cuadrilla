---
description: Cuadrilla — design + security review of current changes (read-only; optional focus as argument)
agent: cuadrilla
---

REVIEW MODE — do not modify production code and do not commit.

Review the current uncommitted changes (or, if there are none, the last commit).
Optional focus from the user: $ARGUMENTS

Changed files:
!`git status --short 2>/dev/null | head -80`

Diff size:
!`git diff --stat 2>/dev/null | tail -5`

Steps:
1. Read the diff yourself to understand the intent of the change.
2. In parallel, delegate:
   - `cuadrilla-architect` (review mode): design, boundaries, SOLID and fit with existing patterns in the changed code.
   - `cuadrilla-qa`: security audit of the changed code, plus run the existing test suite and report results. It must not write new tests unless coverage of a critical path is missing — in that case it lists them instead of writing them.
3. Merge both reports into one list ordered by severity, removing duplicates. For each finding: location, problem, fix, owner agent.
4. Give a clear verdict: **ready to merge**, **merge after fixes** (list the blocking ones), or **needs rework**.
5. Offer to delegate the fixes.
