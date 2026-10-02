# Changelog

## Unreleased
- Windows: `install.ps1` stops on git failures with a clear error, works when `CUADRILLA_REF` is a tag (no `pull` on a detached HEAD), adds `-Ref`, never creates folders on uninstall, and prints next steps.
- Linux/macOS: `install.sh` no longer swallows `pull` errors on branches and handles tags explicitly.
- README (EN/ES): separate install instructions per OS, how to pin a release, update/uninstall per OS, Windows troubleshooting.
- CI: end-to-end installer tests (`scripts/test-install.sh`, `scripts/test-install.ps1`) on Ubuntu and on Windows (PowerShell 5.1 and 7), plus shellcheck and PSScriptAnalyzer; CI also runs on `v*` tags.

## v0.1.0 — 2026-09-28
- Orchestrator `cuadrilla` with T0–T3 triage, grounded planning, self-contained briefs, verification gates and retry limits.
- Specialists: architect, backend, frontend, mobile, devops, qa, git — standard report format, `task: deny`, ordered permissions.
- Commands: `/cuadrilla-plan`, `/cuadrilla-review`, `/cuadrilla-commit`.
- Installers (bash, PowerShell), validator and CI.
