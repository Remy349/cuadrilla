# Changelog

## Unreleased
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
