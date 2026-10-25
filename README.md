# Cuadrilla

**A tech-lead orchestrator and a crew of specialist subagents for [OpenCode](https://opencode.ai).**

*Cuadrilla* (Spanish: *a work crew*) turns OpenCode into a small engineering team: one orchestrator that triages, plans, delegates and verifies — and eight specialists that do the work inside strict, audited permission boundaries. Works with OpenCode 1.x and 2.x.

[Español](README.es.md)

```
you ──▶ cuadrilla (orchestrator) ──┬──▶ cuadrilla-explore    read-only discovery
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
- **Grounded plans.** The orchestrator inspects the repo (or sends `cuadrilla-explore`) before planning — stack, scripts, conventions, relevant files.
- **Self-contained briefs.** Subagents start with an empty context, so every delegation carries goal, context, scope, out-of-scope, acceptance criteria and constraints.
- **Verification gates.** Reports follow a fixed format with the *actual* commands run. The orchestrator checks them against acceptance criteria, retries at most twice, then escalates. Security/QA is mandatory for auth, payments, PII and public endpoints.
- **Safe parallelism.** Only independent tasks on disjoint files run in parallel; contracts are defined before consumers are built.
- **Permissions that actually hold.** Each agent's rules are ordered correctly (in OpenCode the *last* matching rule wins), subagents cannot spawn subagents, only `cuadrilla-git` can commit, and force-push / `reset --hard` / `git clean` are denied outright. Every agent asks before reading `.env` files and before touching anything outside the project, and the orchestrator can only delegate to Cuadrilla's own agents — not to built-ins whose permissions it doesn't control.
- **Stack-agnostic.** Specialists detect the language, framework and test runner from the repo instead of assuming one.
- **Prompt-injection aware.** File contents, web pages and subagent reports are treated as data, never as instructions.

## Install

Requires [OpenCode](https://opencode.ai) 1.x or 2.x and `git`. Pick the section for **your shell** — the Linux command does not work in PowerShell (there `curl` is an alias of `Invoke-WebRequest`).

| | Linux · macOS · WSL · Git Bash | Windows (PowerShell 5.1 or 7) |
|---|---|---|
| Installer | `install.sh` | `install.ps1` |
| Global install | symlinks | copies |
| Agents go to | `~/.config/opencode/` | `%USERPROFILE%\.config\opencode\` |
| Clone kept in | `~/.local/share/cuadrilla` | `%LOCALAPPDATA%\cuadrilla` |
| `cuadrilla` command | linked into `~/.local/bin` | the clone's `bin\` added to your user PATH |
| Update | `cuadrilla update` | `cuadrilla update` |

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

**Uninstall:** `cuadrilla uninstall [--project <dir>]` (or `./install.sh --uninstall [--project <dir>]`)

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

**Uninstall:** `cuadrilla uninstall [--project <dir>]` (or `powershell -ExecutionPolicy Bypass -File .\install.ps1 -Uninstall [-Project <dir>]`). Pass `-NoPath` to the installer to leave your PATH alone.

<details>
<summary>Windows troubleshooting</summary>

- **`No se encuentra ningún parámetro... 'fsSL'` / `A parameter cannot be found that matches parameter name 'fsSL'`** — you ran the Linux command in PowerShell. Use the PowerShell command above (or run the Linux one from Git Bash).
- **`git is required`** — install Git (`winget install Git.Git`) and open a new terminal.
- **`running scripts is disabled on this system`** — only affects running `.\install.ps1` from a clone; use `powershell -ExecutionPolicy Bypass -File .\install.ps1` as shown. `irm | iex` is not affected.
- **Corporate network blocks `raw.githubusercontent.com`** — clone the repo (or download the ZIP) and run `install.ps1` from it; it then uses the local files and needs no network.

</details>

### Updating

```bash
cuadrilla update                    # latest version
cuadrilla update --ref <tag>        # a specific release (or a branch: --ref main)
cuadrilla update --project <dir>    # refresh a per-project install (<dir>/.opencode) instead of the global one
cuadrilla version                   # what's installed, and in which format
```

`update` fetches the clone and re-runs the installer from it, so new agents are added and agents a release dropped are removed. An install that follows a branch (`main` by default) is pulled; an install pinned to a release moves to the newest release. The same works without the command: `./install.sh --update` / `.\install.ps1 -Update`.

Installs made before the `cuadrilla` command existed (v0.1.x) need the one-line installer once more to get it — a plain `git pull` would also miss new agents such as `cuadrilla-explore`, which have to be linked. After that, `cuadrilla update` is all you need.

### All platforms

Existing files with the same name are backed up (`*.bak.<timestamp>`), never overwritten silently. Each target gets a `.cuadrilla-manifest` (commit it with per-project installs): it records what Cuadrilla installed, so updates replace and remove only its own unmodified files. Releases are listed in [`CHANGELOG.md`](CHANGELOG.md) and on the [Releases](https://github.com/Remy349/cuadrilla/releases) page; `CUADRILLA_REF` accepts any tag or branch (default `main`).

## OpenCode 1.x and 2.x

Cuadrilla ships agents in two formats, built from one source:

| Format | Files | Read by |
|---|---|---|
| `v1` | `agents/*.md` (the source) | OpenCode 1.x **and** 2.x — 2.x translates V1 frontmatter on load (deprecated, but supported) |
| `v2` | `dist/v2/agents/*.md` (generated) | OpenCode 2.x only: native `permissions` lists, no translation |

The installer picks one with `--format auto|v1|v2` (`-Format` on Windows; default `auto`): `v2` when OpenCode 2.x is the only version on your PATH, `v1` otherwise. **Never use `v2` where any OpenCode 1.x reads the same config**: 1.x doesn't know the `permissions` field and would run the agents with no restrictions. `cuadrilla version` shows the installed format; `cuadrilla update --format v2` switches.

Commands (`commands/*.md`) are the same in both versions.

OpenCode 2.x changed some defaults that Cuadrilla accounts for: it allows `external_directory` (access outside the project) and `websearch` unless a rule says otherwise, and its built-in `explore` agent may run any shell command. Every Cuadrilla agent sets these explicitly, and the orchestrator delegates to its own read-only `cuadrilla-explore` instead.

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

The best cost/quality trade-off is usually a **strong reasoning model for the orchestrator and architect** (routing and planning quality depend on it) and a **fast, cheap model for implementers**. Copy the example for your OpenCode version into `~/.config/opencode/opencode.json` (or merge its agent block) and change the model IDs: [`examples/opencode.json`](examples/opencode.json) (1.x, `agent` key) or [`examples/opencode.v2.json`](examples/opencode.v2.json) (2.x, `agents` key). Run `opencode models` to list what you have. You can also set `steps` per agent to cap iterations and cost.

## Customize

- **Permissions:** override any agent in your `opencode.json` — your rules are applied after Cuadrilla's, so they win. OpenCode 1.x: `agent.<name>.permission` (a map). OpenCode 2.x: `agents.<name>.permissions` (a list of `{ "action", "resource", "effect" }`; `bash` is `shell` and `task` is `subagent` there).
- **Different crew:** add a `agents/cuadrilla-<role>.md` file with `mode: subagent` and `task: deny`, run `python3 scripts/build.py` to generate its V2 version, and add it to the crew table in `agents/cuadrilla.md` so the orchestrator knows when to route there (it may call any `cuadrilla-*` agent). Keep sources in the V1 format: the validator rejects V2 fields in them.
- **Stricter bash:** each implementer auto-allows only test/lint/typecheck/build commands; everything else asks. Add your project's commands (e.g. `make test*`) to the allow list.

## Development

```bash
pip install pyyaml
python3 scripts/build.py             # regenerate dist/v2 after editing agents/ (commit the result)
python3 scripts/validate.py          # lints frontmatter, permissions, references; checks dist/v2 is current
scripts/test-install.sh              # end-to-end test of install.sh + cuadrilla in a temp HOME
pwsh -File scripts/test-install.ps1  # end-to-end test of install.ps1 + cuadrilla.ps1 (Windows, or pwsh elsewhere)

# Check dist/v2 against OpenCode's official V2 schema (what CI runs):
npm install --prefix /tmp/oc-schema @opencode/schema@2.1.4
python3 scripts/build.py --json | OPENCODE_SCHEMA_DIR=/tmp/oc-schema node scripts/check-v2-schema.mjs
```

The validator runs in CI on every PR. It fails on the mistakes that break or weaken agents silently: `*` catch-all not placed first, unknown fields or permission actions (a typo is a rule that never matches), V1 and V2 fields mixed in one file, deprecated `tools:`, subagents without `task: deny`, agents that don't set `external_directory` / `websearch` or that read `.env` without asking, references to agents that don't exist, and a `dist/v2` that is out of date.

CI also runs both installer tests — `install.sh` on Ubuntu (plus shellcheck) and `install.ps1` on Windows under both PowerShell 5.1 and 7 (plus PSScriptAnalyzer) — covering global, per-project, format selection, backups, the manifest, uninstall, installs pinned to a tag and `cuadrilla update`.

**Releasing** is automated. Rename the top `## Unreleased` entry of `CHANGELOG.md` to `## vX.Y.Z — date` and merge to `main`: once every check passes, CI tags that commit and publishes the GitHub Release with the entry as notes ([`scripts/release.sh`](scripts/release.sh)). A release that failed halfway can be finished by re-running the **validate** workflow on `main` from the Actions tab. To tag an older commit, run `scripts/release.sh vX.Y.Z <commit>` locally with your own credentials (CI's token is not allowed to tag commits whose workflow files differ). Tags are never moved once pushed; preview with `scripts/release.sh --dry-run`.

## License

MIT © Santiago Moraga
