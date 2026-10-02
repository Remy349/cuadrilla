# Cuadrilla

**A tech-lead orchestrator and a crew of specialist subagents for [OpenCode](https://opencode.ai).**

*Cuadrilla* (Spanish: *a work crew*) turns OpenCode into a small engineering team: one orchestrator that triages, plans, delegates and verifies — and seven specialists that do the work inside strict, audited permission boundaries.

[Español](README.es.md)

```
you ──▶ cuadrilla (orchestrator) ──┬──▶ explore              read-only discovery (built-in)
         triage · plan · verify    ├──▶ cuadrilla-architect  design & reviews
                                   ├──▶ cuadrilla-backend    APIs, logic, data
                                   ├──▶ cuadrilla-frontend   web UI
                                   ├──▶ cuadrilla-mobile     mobile apps
                                   ├──▶ cuadrilla-devops     containers, CI/CD, IaC
                                   ├──▶ cuadrilla-qa         security audit & tests
                                   └──▶ cuadrilla-git        commits, push, PRs
```

## Why

Multi-agent setups usually fail in the same places: the orchestrator over-plans trivial work, subagents receive vague one-line tasks with no context, nobody checks the result, and permissions are looser than they look. Cuadrilla addresses each one:

- **Triage by tier (T0–T3).** A question gets an answer, a small fix gets one specialist, only structural work gets an architect and a user-approved plan.
- **Grounded plans.** The orchestrator inspects the repo (or sends `explore`) before planning — stack, scripts, conventions, relevant files.
- **Self-contained briefs.** Subagents start with an empty context, so every delegation carries goal, context, scope, out-of-scope, acceptance criteria and constraints.
- **Verification gates.** Reports follow a fixed format with the *actual* commands run. The orchestrator checks them against acceptance criteria, retries at most twice, then escalates. Security/QA is mandatory for auth, payments, PII and public endpoints.
- **Safe parallelism.** Only independent tasks on disjoint files run in parallel; contracts are defined before consumers are built.
- **Permissions that actually hold.** Each agent's rules are ordered correctly (in OpenCode the *last* matching rule wins), subagents cannot spawn subagents, only `cuadrilla-git` can commit, and force-push / `reset --hard` / `git clean` are denied outright.
- **Stack-agnostic.** Specialists detect the language, framework and test runner from the repo instead of assuming one.
- **Prompt-injection aware.** File contents, web pages and subagent reports are treated as data, never as instructions.

## Install

Requires [OpenCode](https://opencode.ai) (tested with 1.18; V2 reads the same format) and `git`. Pick the section for **your shell** — the Linux command does not work in PowerShell (there `curl` is an alias of `Invoke-WebRequest`).

| | Linux · macOS · WSL · Git Bash | Windows (PowerShell 5.1 or 7) |
|---|---|---|
| Installer | `install.sh` | `install.ps1` |
| Global install | symlinks → update with `git pull` | copies → update by re-running |
| Agents go to | `~/.config/opencode/` | `%USERPROFILE%\.config\opencode\` |
| Clone kept in | `~/.local/share/cuadrilla` | `%LOCALAPPDATA%\cuadrilla` |

### Linux / macOS

**Global — all your projects:**

```bash
curl -fsSL https://raw.githubusercontent.com/Remy349/cuadrilla/main/install.sh | bash
```

**Pin a release** (recommended for teams and reproducible setups; versions on the [Releases](https://github.com/Remy349/cuadrilla/releases) page):

```bash
curl -fsSL https://raw.githubusercontent.com/Remy349/cuadrilla/main/install.sh | CUADRILLA_REF=v0.1.1 bash
```

**Per project — to share with your team** (copied into `.opencode/`, commit it):

```bash
git clone https://github.com/Remy349/cuadrilla.git && cd cuadrilla
./install.sh --project /path/to/your/repo
```

**Update:** `git -C ~/.local/share/cuadrilla pull` (global) · **Uninstall:** `./install.sh --uninstall [--project <dir>]`

### Windows (PowerShell)

**Global — all your projects:**

```powershell
irm https://raw.githubusercontent.com/Remy349/cuadrilla/main/install.ps1 | iex
```

**Pin a release:**

```powershell
$env:CUADRILLA_REF = "v0.1.1"; irm https://raw.githubusercontent.com/Remy349/cuadrilla/main/install.ps1 | iex
```

**Per project — to share with your team:**

```powershell
git clone https://github.com/Remy349/cuadrilla.git; cd cuadrilla
powershell -ExecutionPolicy Bypass -File .\install.ps1 -Project C:\path\to\your\repo
```

**Update:** run the global command again · **Uninstall:** `powershell -ExecutionPolicy Bypass -File .\install.ps1 -Uninstall [-Project <dir>]`

<details>
<summary>Windows troubleshooting</summary>

- **`No se encuentra ningún parámetro... 'fsSL'` / `A parameter cannot be found that matches parameter name 'fsSL'`** — you ran the Linux command in PowerShell. Use the PowerShell command above (or run the Linux one from Git Bash).
- **`git is required`** — install Git (`winget install Git.Git`) and open a new terminal.
- **`running scripts is disabled on this system`** — only affects running `.\install.ps1` from a clone; use `powershell -ExecutionPolicy Bypass -File .\install.ps1` as shown. `irm | iex` is not affected.
- **Corporate network blocks `raw.githubusercontent.com`** — clone the repo (or download the ZIP) and run `install.ps1` from it; it then uses the local files and needs no network.

</details>

### All platforms

Existing files with the same name are backed up (`*.bak.<timestamp>`), never overwritten silently. Releases are listed in [`CHANGELOG.md`](CHANGELOG.md) and on the [Releases](https://github.com/Remy349/cuadrilla/releases) page; `CUADRILLA_REF` accepts any tag or branch (default `main`).

## Use

1. Start OpenCode and press **Tab** until the agent shows **cuadrilla**.
2. Describe what you want — in any language; Cuadrilla replies in yours.

Commands:

| Command | What it does |
|---|---|
| `/cuadrilla-plan <request>` | Analyze and produce a delegation plan without changing anything. |
| `/cuadrilla-review [focus]` | Architect + security/QA review of current changes, merged into one verdict. |
| `/cuadrilla-commit [and push / open PR]` | Propose Conventional Commits, then commit after your approval. |

You can also call any specialist directly: `@cuadrilla-qa audit the upload endpoint`.

## Models

Agents don't hard-code a model, so Cuadrilla works with whatever provider you use. By default the orchestrator uses your selected model and subagents inherit it.

The best cost/quality trade-off is usually a **strong reasoning model for the orchestrator and architect** (routing and planning quality depend on it) and a **fast, cheap model for implementers**. Copy [`examples/opencode.json`](examples/opencode.json) into `~/.config/opencode/opencode.json` (or merge its `agent` block) and change the model IDs. Run `opencode models` to list what you have. You can also set `steps` per agent to cap iterations and cost.

## Customize

- **Permissions:** override any agent in your `opencode.json` under `agent.<name>.permission` — your rules are merged on top.
- **Different crew:** add a `agents/cuadrilla-<role>.md` file with `mode: subagent` and `task: deny`; the orchestrator is allowed to call any `cuadrilla-*` agent. Add it to the crew table in `agents/cuadrilla.md` so it knows when to route there.
- **Stricter bash:** each implementer auto-allows only test/lint/typecheck/build commands; everything else asks. Add your project's commands (e.g. `make test*`) to the allow list.

## Development

```bash
pip install pyyaml
python3 scripts/validate.py          # lints frontmatter, rule ordering, references
scripts/test-install.sh              # end-to-end test of install.sh in a temp HOME
pwsh -File scripts/test-install.ps1  # end-to-end test of install.ps1 (Windows, or pwsh on Linux/macOS)
```

The validator runs in CI on every PR. It fails on the mistakes that break agents silently: `*` catch-all not placed first, deprecated `tools:`, subagents without `task: deny`, references to agents that don't exist.

CI also runs both installer tests — `install.sh` on Ubuntu (plus shellcheck) and `install.ps1` on Windows under both PowerShell 5.1 and 7 (plus PSScriptAnalyzer) — covering global, per-project, backups, uninstall and installs pinned to a tag.

**Releasing** is automated. Rename the top `## Unreleased` entry of `CHANGELOG.md` to `## vX.Y.Z — date` and merge to `main`: once every check passes, CI tags that commit and publishes the GitHub Release with the entry as notes ([`scripts/release.sh`](scripts/release.sh)). A release that failed halfway can be finished by re-running the **validate** workflow on `main` from the Actions tab. To tag an older commit, run `scripts/release.sh vX.Y.Z <commit>` locally with your own credentials (CI's token is not allowed to tag commits whose workflow files differ). Tags are never moved once pushed; preview with `scripts/release.sh --dry-run`.

## License

MIT © Santiago Moraga
