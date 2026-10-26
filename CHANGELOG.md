# Changelog

## v0.2.0 — 2026-10-26

OpenCode 2.x support, hardened permissions and a `cuadrilla` command.

- **Security — OpenCode 2.x defaults:** 2.x allows `external_directory` and `websearch` unless a rule says otherwise (1.x asked for out-of-project access). Every agent now sets both: `external_directory` asks (implementers, orchestrator) or is denied (architect, explore, git); `websearch` asks like `webfetch` (denied for git). `browser` is set too.
- **Security — no more built-in `explore`:** in 2.x it may run any shell command and use the web. The orchestrator now delegates to a new read-only `cuadrilla-explore` (read/glob/grep, read-only git and `ls`, no network, no out-of-project access) and can't reach built-in agents.
- **Security — secrets:** every agent asks before reading `.env` / `.env.*` (`.env.example` stays readable); a plain `read: allow` used to override OpenCode's own `.env` prompt.
- **Security — git/devops:** `cuadrilla-git` may only list branches freely; forced deletes/moves (`-D`, `-M`, `-C`, `-f`, `--force`) are denied and other branch commands ask. `cuadrilla-devops` can't read Kubernetes secrets (`kubectl get/describe secret`).
- **OpenCode 2.x native format:** `scripts/build.py` generates `dist/v2/agents/` (permission lists, `shell`/`subagent`, `request.body.temperature`) from the V1 sources, mirroring 2.x's own translator. Installers pick the format with `--format auto|v1|v2` / `-Format` (auto: v2 only when 2.x is the only OpenCode on PATH — 1.x would ignore V2 permissions).
- **`cuadrilla` command:** `cuadrilla update [--ref <tag|branch>] [--project <dir>] [--format …]`, `cuadrilla version`, `cuadrilla uninstall`. Linked into `~/.local/bin` (Linux/macOS) or added to the user PATH (Windows, opt out with `-NoPath`). Also available as `install.sh --update` / `install.ps1 -Update`. A pinned install updates to the newest release; a branch install is pulled.
- **Installers:** a `.cuadrilla-manifest` records installed files, so updates remove agents a release dropped and no longer back up Cuadrilla's own previous copies (Windows used to create a `.bak` on every update). `install.sh` stays compatible with macOS's bash 3.2.
- **Validator:** rejects unknown fields and permission actions, V1/V2 fields mixed in one file, missing `external_directory`/`websearch` rules, unprotected `.env` reads, and a stale `dist/v2`. CI also decodes `dist/v2` with OpenCode's official schema (`@opencode/schema` 2.1.4). `.gitattributes` keeps LF endings.
- Release automation: finishes a release whose tag exists but whose GitHub Release is missing; release runs are serialized; manual backfill inputs removed (GitHub's `GITHUB_TOKEN` cannot tag commits whose workflow files differ — backfill locally with `scripts/release.sh vX.Y.Z <commit>`). Local runs tag with your own git identity.
- README/installers: pin examples point to the published `v0.1.1` (they referenced the untagged `v0.1.0`) and link the Releases page.
- CI: `actions/checkout@v5` and `actions/setup-python@v6` (Node 20 is deprecated on runners).

## v0.1.1 — 2026-10-02
- Windows: `install.ps1` stops on git failures with a clear error, works when `CUADRILLA_REF` is a tag (no `pull` on a detached HEAD), adds `-Ref`, never creates folders on uninstall, and prints next steps.
- Linux/macOS: `install.sh` no longer swallows `pull` errors on branches and handles tags explicitly.
- README (EN/ES): separate install instructions per OS, how to pin a release, update/uninstall per OS, Windows troubleshooting.
- CI: end-to-end installer tests (`scripts/test-install.sh`, `scripts/test-install.ps1`) on Ubuntu and on Windows (PowerShell 5.1 and 7), plus shellcheck and PSScriptAnalyzer; CI also runs on `v*` tags.
- Releases are automated: pushing a CHANGELOG whose top entry is an untagged version to `main` tags it and publishes the GitHub Release once CI passes (`scripts/release.sh`); older versions can be released on demand from the Actions tab.

## v0.1.0 — 2026-09-28
- Orchestrator `cuadrilla` with T0–T3 triage, grounded planning, self-contained briefs, verification gates and retry limits.
- Specialists: architect, backend, frontend, mobile, devops, qa, git — standard report format, `task: deny`, ordered permissions.
- Commands: `/cuadrilla-plan`, `/cuadrilla-review`, `/cuadrilla-commit`.
- Installers (bash, PowerShell), validator and CI.
