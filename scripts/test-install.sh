#!/usr/bin/env bash
# End-to-end test for install.sh in an isolated HOME (nothing outside a temp dir is touched).
# Covers: global (symlink), project (copy), uninstall, backups, and remote installs
# pinned to a tag, re-run on the tag, then switched to a branch.
#
# Usage: scripts/test-install.sh
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

unset XDG_CONFIG_HOME XDG_DATA_HOME CUADRILLA_HOME CUADRILLA_REF CUADRILLA_REPO
export HOME="$tmp/home"
mkdir -p "$HOME"
config="$HOME/.config/opencode"
clone="$HOME/.local/share/cuadrilla"
tag="v0.0.0-test"

pass() { printf 'ok - %s\n' "$*"; }
fail() { printf 'FAIL - %s\n' "$*" >&2; exit 1; }

# Fixture repo with the working tree's agents/commands, a tag and a branch.
fixture="$tmp/src"
git init -q -b main "$fixture"
cp -r "$root/agents" "$root/commands" "$fixture/"
git -C "$fixture" add .
git -C "$fixture" -c user.name=ci -c user.email=ci@example.invalid commit -qm fixture
git -C "$fixture" tag "$tag"

# --- From a clone -------------------------------------------------------------
"$root/install.sh" >/dev/null
[[ -L "$config/agents/cuadrilla.md" ]] || fail "global install symlinks agents"
[[ -L "$config/commands/cuadrilla-plan.md" ]] || fail "global install symlinks commands"
pass "global install (symlink)"

"$root/install.sh" --uninstall >/dev/null
[[ ! -e "$config/agents/cuadrilla.md" ]] || fail "uninstall removes agents"
pass "global uninstall"

mkdir -p "$tmp/proj"
"$root/install.sh" --project "$tmp/proj" >/dev/null
[[ -f "$tmp/proj/.opencode/agents/cuadrilla.md" && ! -L "$tmp/proj/.opencode/agents/cuadrilla.md" ]] \
  || fail "project install copies files"
pass "project install (copy)"

echo "mine" > "$tmp/proj/.opencode/agents/cuadrilla.md"
"$root/install.sh" --project "$tmp/proj" >/dev/null
compgen -G "$tmp/proj/.opencode/agents/cuadrilla.md.bak.*" >/dev/null || fail "foreign file is backed up"
pass "backup of a modified file"

# --- Remote (piped, as with curl | bash) -------------------------------------
remote() { CUADRILLA_REPO="$fixture" bash -s -- "$@" < "$root/install.sh" >/dev/null; }

CUADRILLA_REF="$tag" remote
[[ "$(git -C "$clone" describe --tags --exact-match)" == "$tag" ]] || fail "remote install checks out the tag"
[[ -L "$config/agents/cuadrilla.md" ]] || fail "remote install links agents"
pass "remote install pinned to $tag"

CUADRILLA_REF="$tag" remote
pass "remote re-install on a tag (no pull on detached HEAD)"

CUADRILLA_REF=main remote
[[ "$(git -C "$clone" branch --show-current)" == "main" ]] || fail "switch from tag to branch"
pass "remote switch from tag to main"

remote --uninstall
[[ ! -e "$config/agents/cuadrilla.md" ]] || fail "remote uninstall"
pass "remote uninstall"
