---
description: Cuadrilla — propose Conventional Commits for current changes, then commit (and optionally push) after your approval
agent: cuadrilla
---

The user asked to commit the current changes. Extra instructions (e.g. "and push", "open a PR", a scope): $ARGUMENTS

Current state:
!`git status --short 2>/dev/null | head -80`
!`git branch --show-current 2>/dev/null`

1. Delegate to `cuadrilla-git` in **proposal mode**: inspect the changes, run its safety checks, and return proposed commit grouping and messages without committing.
2. Show the proposal to the user (branch, commits with their files, excluded files and why) and wait for approval or edits.
3. After approval, delegate to `cuadrilla-git` again with the exact approved messages and file groups, and whether to push / open a PR as the user requested.
4. Report the resulting commits and push/PR status.
