#!/usr/bin/env bash
# Cuadrilla installer for OpenCode — https://github.com/OWNER/cuadrilla
#
#   Global (all projects), symlinked so `git pull` updates it:
#     curl -fsSL https://raw.githubusercontent.com/OWNER/cuadrilla/main/install.sh | bash
#   or, from a clone:
#     ./install.sh
#
#   Into the current project (copied, so your team can commit it):
#     ./install.sh --project [dir]
#
#   Remove:
#     ./install.sh --uninstall [--project [dir]]
set -euo pipefail

REPO_URL="${CUADRILLA_REPO:-https://github.com/OWNER/cuadrilla.git}"
REF="${CUADRILLA_REF:-main}"
CLONE_DIR="${CUADRILLA_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/cuadrilla}"

scope="global"
project_dir=""
action="install"
link_mode=""

usage() {
  sed -n '2,15p' "$0" 2>/dev/null | sed 's/^# \{0,1\}//'
  cat <<'EOF'
Options:
  --project [dir]   Install into <dir>/.opencode (default: current directory)
  --copy            Copy files instead of symlinking (default for --project)
  --link            Symlink files (default for global)
  --uninstall       Remove Cuadrilla agents and commands from the target
  -h, --help        Show this help
Environment:
  CUADRILLA_REF     Git branch or tag to install (default: main), e.g. v0.1.0
  CUADRILLA_HOME    Where the repo is cloned for remote installs
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project)
      scope="project"
      if [[ $# -gt 1 && "${2:0:1}" != "-" ]]; then project_dir="$2"; shift; fi
      ;;
    --copy) link_mode="copy" ;;
    --link) link_mode="link" ;;
    --uninstall) action="uninstall" ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
  shift
done

info() { printf '\033[1;33m▸\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m✓\033[0m %s\n' "$*"; }

# --- Locate the source files (local clone or fetch) -------------------------
script_dir=""
if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]; then
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

if [[ -n "$script_dir" && -d "$script_dir/agents" ]]; then
  src="$script_dir"
else
  command -v git >/dev/null || { echo "git is required" >&2; exit 1; }
  if [[ -d "$CLONE_DIR/.git" ]]; then
    info "Updating $CLONE_DIR ($REF)"
    git -C "$CLONE_DIR" fetch --quiet --tags origin
    git -C "$CLONE_DIR" checkout --quiet "$REF"
    git -C "$CLONE_DIR" pull --quiet --ff-only origin "$REF" 2>/dev/null || true
  else
    info "Cloning $REPO_URL ($REF) into $CLONE_DIR"
    mkdir -p "$(dirname "$CLONE_DIR")"
    git clone --quiet --branch "$REF" "$REPO_URL" "$CLONE_DIR"
  fi
  src="$CLONE_DIR"
fi

# --- Resolve target ----------------------------------------------------------
if [[ "$scope" == "global" ]]; then
  target="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
  [[ -z "$link_mode" ]] && link_mode="link"
else
  target="$(cd "${project_dir:-.}" && pwd)/.opencode"
  [[ -z "$link_mode" ]] && link_mode="copy"
fi

stamp="$(date +%Y%m%d%H%M%S)"
count=0

for kind in agents commands; do
  mkdir -p "$target/$kind"
  for file in "$src/$kind"/*.md; do
    [[ -e "$file" ]] || continue
    name="$(basename "$file")"
    dest="$target/$kind/$name"

    if [[ "$action" == "uninstall" ]]; then
      if [[ -L "$dest" || -f "$dest" ]]; then rm -f "$dest"; ok "removed $kind/$name"; count=$((count+1)); fi
      continue
    fi

    # Back up anything that isn't already ours
    if [[ -e "$dest" && ! -L "$dest" ]] && ! cmp -s "$file" "$dest"; then
      mv "$dest" "$dest.bak.$stamp"
      info "backed up existing $kind/$name → $name.bak.$stamp"
    fi
    rm -f "$dest"
    if [[ "$link_mode" == "link" ]]; then ln -s "$file" "$dest"; else cp "$file" "$dest"; fi
    count=$((count+1))
  done
done

if [[ "$action" == "uninstall" ]]; then
  ok "Uninstalled $count files from $target"
  exit 0
fi

ok "Installed $count files into $target ($link_mode)"
cat <<EOF

Next steps:
  1. Restart OpenCode.
  2. Press Tab until you see the "cuadrilla" agent, then describe what you want.
  3. Try:  /cuadrilla-plan add rate limiting to the login endpoint
  4. Optional: set per-agent models — see examples/opencode.json in $src
EOF
if [[ "$link_mode" == "link" ]]; then
  echo "  Update later with:  git -C \"$src\" pull"
fi
