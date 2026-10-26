#!/usr/bin/env bash
# End-to-end test for install.sh and bin/cuadrilla in an isolated HOME (nothing outside a
# temp dir is touched). Covers: global (symlink) and project (copy) installs, format
# selection (auto/v1/v2 with fake OpenCode binaries), backups, the manifest (no spurious
# backups, stale files removed), uninstall, remote installs pinned to a tag, and
# `cuadrilla update` moving between releases and branches.
#
# Usage: scripts/test-install.sh
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

unset XDG_CONFIG_HOME XDG_DATA_HOME CUADRILLA_HOME CUADRILLA_REF CUADRILLA_REPO CUADRILLA_FORMAT CUADRILLA_BIN_DIR
export HOME="$tmp/home"
mkdir -p "$HOME"
config="$HOME/.config/opencode"
clone="$HOME/.local/share/cuadrilla"
cli="$HOME/.local/bin/cuadrilla"
tag="v0.0.1"

pass() { printf 'ok - %s\n' "$*"; }
fail() { printf 'FAIL - %s\n' "$*" >&2; exit 1; }
target_of() { readlink "$1"; }
commit() { git -C "$fixture" add -A && git -C "$fixture" -c user.name=ci -c user.email=ci@example.invalid commit -qm "$1"; }

# Fake OpenCode binaries: auto-detection reads `opencode --version` / `opencode2 --version`.
fakebin="$tmp/fakebin"
mkdir -p "$fakebin"
export PATH="$fakebin:$PATH"
fake_opencode() {  # fake_opencode <binary> <version|"">
  printf '#!/bin/sh\necho "%s"\n' "$2" > "$fakebin/$1"
  chmod +x "$fakebin/$1"
}
fake_opencode opencode ""   # an unknown version counts as "not found"
fake_opencode opencode2 ""

# Fixture repo: a copy of the working tree's installable files, with a release tag.
fixture="$tmp/src"
git init -q -b main "$fixture"
cp -r "$root/agents" "$root/commands" "$root/dist" "$root/bin" "$root/install.sh" "$fixture/"
commit fixture
git -C "$fixture" tag "$tag"

# --- From a clone -------------------------------------------------------------
"$root/install.sh" >/dev/null
[[ -L "$config/agents/cuadrilla.md" ]] || fail "global install symlinks agents"
[[ -L "$config/commands/cuadrilla-plan.md" ]] || fail "global install symlinks commands"
[[ "$(target_of "$config/agents/cuadrilla.md")" == "$root/agents/cuadrilla.md" ]] || fail "no OpenCode found → v1 format"
[[ -f "$config/.cuadrilla-manifest" ]] || fail "manifest written"
[[ -L "$cli" && -x "$cli" ]] || fail "cuadrilla command linked"
[[ "$("$cli" version)" == "cuadrilla "* ]] || fail "cuadrilla version"
pass "global install (symlink, v1 when OpenCode isn't found, cuadrilla command)"

fake_opencode opencode "opencode 2.1.4"
"$root/install.sh" >/dev/null
[[ "$(target_of "$config/agents/cuadrilla.md")" == "$root/dist/v2/agents/cuadrilla.md" ]] || fail "only V2 → v2 format"
pass "auto format: only OpenCode 2.x → v2"

fake_opencode opencode2 "2.1.4"
fake_opencode opencode "1.19.4"
"$root/install.sh" >/dev/null
[[ "$(target_of "$config/agents/cuadrilla.md")" == "$root/agents/cuadrilla.md" ]] || fail "V1 and V2 → v1 format"
pass "auto format: OpenCode 1.x and 2.x → v1"

"$root/install.sh" --format v2 >/dev/null
[[ "$(target_of "$config/agents/cuadrilla.md")" == "$root/dist/v2/agents/cuadrilla.md" ]] || fail "--format v2"
grep -q '^# format: v2' "$config/.cuadrilla-manifest" || fail "manifest records the format"
pass "--format v2"
fake_opencode opencode ""
fake_opencode opencode2 ""

"$root/install.sh" --uninstall >/dev/null
[[ ! -e "$config/agents/cuadrilla.md" ]] || fail "uninstall removes agents"
[[ ! -e "$config/.cuadrilla-manifest" ]] || fail "uninstall removes the manifest"
[[ ! -e "$cli" ]] || fail "uninstall removes the cuadrilla command"
pass "global uninstall"

mkdir -p "$tmp/proj"
proj_agent="$tmp/proj/.opencode/agents/cuadrilla.md"
"$root/install.sh" --project "$tmp/proj" >/dev/null
[[ -f "$proj_agent" && ! -L "$proj_agent" ]] || fail "project install copies files"
pass "project install (copy)"

"$root/install.sh" --project "$tmp/proj" --format v2 >/dev/null
cmp -s "$proj_agent" "$root/dist/v2/agents/cuadrilla.md" || fail "project switched to v2"
! compgen -G "$tmp/proj/.opencode/agents/*.bak.*" >/dev/null || fail "no backup of our own previous copy"
pass "project update replaces its own copies without backups"

echo "mine" > "$proj_agent"
"$root/install.sh" --project "$tmp/proj" >/dev/null
compgen -G "$proj_agent.bak.*" >/dev/null || fail "foreign file is backed up"
pass "backup of a modified file"

# --- Remote (piped, as with curl | bash) -------------------------------------
remote() { CUADRILLA_REPO="$fixture" bash -s -- "$@" < "$root/install.sh" >/dev/null; }

CUADRILLA_REF="$tag" remote
[[ "$(git -C "$clone" describe --tags --exact-match)" == "$tag" ]] || fail "remote install checks out the tag"
[[ -L "$config/agents/cuadrilla.md" ]] || fail "remote install links agents"
[[ "$(cd "$(dirname "$(target_of "$cli")")" && pwd)" == "$clone/bin" ]] || fail "cuadrilla command points at the clone"
pass "remote install pinned to $tag"

CUADRILLA_REF="$tag" remote
pass "remote re-install on a tag (no pull on detached HEAD)"

# --- cuadrilla update -----------------------------------------------------------
# A new release that drops one agent and adds another.
git -C "$fixture" rm -q agents/cuadrilla-mobile.md
cp "$fixture/agents/cuadrilla-qa.md" "$fixture/agents/cuadrilla-newcomer.md"
commit "release 0.0.2"
git -C "$fixture" tag v0.0.2

"$cli" update >/dev/null
[[ "$(git -C "$clone" describe --tags --exact-match)" == "v0.0.2" ]] || fail "update moves a pinned install to the newest release"
[[ -L "$config/agents/cuadrilla-newcomer.md" ]] || fail "update links new agents"
[[ ! -e "$config/agents/cuadrilla-mobile.md" && ! -L "$config/agents/cuadrilla-mobile.md" ]] \
  || fail "update removes agents that were dropped"
pass "cuadrilla update: pinned → newest release, new agents linked, dropped ones removed"

"$cli" update --ref main >/dev/null
[[ "$(git -C "$clone" branch --show-current)" == "main" ]] || fail "update --ref main"
echo "# change" >> "$fixture/commands/cuadrilla-plan.md"
commit "unreleased change"
"$cli" update >/dev/null
[[ "$(git -C "$clone" rev-parse HEAD)" == "$(git -C "$fixture" rev-parse HEAD)" ]] || fail "update pulls a branch"
pass "cuadrilla update: --ref main, then pulls the branch"

"$cli" update --project "$tmp/proj" >/dev/null
[[ -f "$tmp/proj/.opencode/agents/cuadrilla-newcomer.md" ]] || fail "update --project refreshes a project"
[[ ! -e "$tmp/proj/.opencode/agents/cuadrilla-mobile.md" ]] || fail "update --project removes dropped agents"
pass "cuadrilla update --project"

CUADRILLA_REF=main remote
[[ "$(git -C "$clone" branch --show-current)" == "main" ]] || fail "switch from tag to branch"
pass "remote install on main"

"$cli" uninstall >/dev/null
[[ ! -e "$config/agents/cuadrilla.md" && ! -e "$cli" ]] || fail "cuadrilla uninstall"
pass "cuadrilla uninstall"

remote --format v2
[[ "$(target_of "$config/agents/cuadrilla.md")" == "$clone/dist/v2/agents/cuadrilla.md" ]] || fail "remote --format v2"
remote --uninstall
[[ ! -e "$config/agents/cuadrilla.md" ]] || fail "remote uninstall"
pass "remote install with --format v2, then remote uninstall"
