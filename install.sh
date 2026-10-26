#!/usr/bin/env bash
# Cuadrilla installer for OpenCode — https://github.com/Remy349/cuadrilla
#
#   Global (all projects), symlinked, plus the `cuadrilla` command in ~/.local/bin:
#     curl -fsSL https://raw.githubusercontent.com/Remy349/cuadrilla/main/install.sh | bash
#   Pin a version (remote installs only; a clone installs whatever it has checked out):
#     curl -fsSL https://raw.githubusercontent.com/Remy349/cuadrilla/main/install.sh | CUADRILLA_REF=v0.2.0 bash
#   or, from a clone:
#     ./install.sh
#
#   Update an existing install (same as `cuadrilla update`):
#     ./install.sh --update [--ref <tag|branch>] [--project [dir]]
#
#   Into the current project (copied, so your team can commit it):
#     ./install.sh --project [dir]
#
#   Remove:
#     ./install.sh --uninstall [--project [dir]]
set -euo pipefail

REPO_URL="${CUADRILLA_REPO:-https://github.com/Remy349/cuadrilla.git}"
REF="${CUADRILLA_REF:-main}"
CLONE_DIR="${CUADRILLA_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/cuadrilla}"
BIN_DIR="${CUADRILLA_BIN_DIR:-$HOME/.local/bin}"
MANIFEST=".cuadrilla-manifest"

scope="global"
project_dir=""
action="install"
link_mode=""
format="${CUADRILLA_FORMAT:-auto}"
ref_opt=""
passthru=()  # arguments forwarded when --update re-runs the updated installer

usage() {
  sed -n '2,21p' "$0" 2>/dev/null | sed 's/^# \{0,1\}//'
  cat <<'EOF'
Options:
  --project [dir]   Install into <dir>/.opencode (default: current directory)
  --copy            Copy files instead of symlinking (default for --project)
  --link            Symlink files (default for global)
  --format <f>      auto (default), v1 or v2 — which agent format to install (see below)
  --update          Update the Cuadrilla clone, then reinstall from it
  --ref <ref>       Tag or branch to install or update to (e.g. v0.2.0, main)
  --uninstall       Remove Cuadrilla agents, commands and the cuadrilla command
  -h, --help        Show this help
Formats:
  v1    The V1 frontmatter. Read by OpenCode 1.x and 2.x (2.x translates it; deprecated).
  v2    Native OpenCode 2.x files. OpenCode 1.x would ignore their permissions: never
        use them where any OpenCode 1.x reads this config.
  auto  v2 if OpenCode 2.x is the only version found on PATH, otherwise v1.
Environment:
  CUADRILLA_REF     Git branch or tag to install (default: main), e.g. v0.2.0
  CUADRILLA_FORMAT  Same as --format
  CUADRILLA_REPO    Git URL to clone (default: the GitHub repo)
  CUADRILLA_HOME    Where the repo is cloned for remote installs
  CUADRILLA_BIN_DIR Where the cuadrilla command is linked (default: ~/.local/bin)
EOF
}

die() { printf '\033[1;31m✗\033[0m %s\n' "$*" >&2; exit 1; }
info() { printf '\033[1;33m▸\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m✓\033[0m %s\n' "$*"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project)
      scope="project"; passthru+=("$1")
      if [[ $# -gt 1 && "${2:0:1}" != "-" ]]; then project_dir="$2"; passthru+=("$2"); shift; fi
      ;;
    --copy) link_mode="copy"; passthru+=("$1") ;;
    --link) link_mode="link"; passthru+=("$1") ;;
    --format)
      [[ $# -gt 1 ]] || die "--format needs a value: auto, v1 or v2"
      format="$2"; passthru+=("$1" "$2"); shift
      ;;
    --ref)
      [[ $# -gt 1 ]] || die "--ref needs a tag or branch"
      ref_opt="$2"; REF="$2"; shift
      ;;
    --update) action="update" ;;
    --uninstall) action="uninstall"; passthru+=("$1") ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
  shift
done
[[ "$format" =~ ^(auto|v1|v2)$ ]] || die "invalid format '$format' (expected auto, v1 or v2)"

describe() { git -C "$1" describe --tags --always 2>/dev/null || echo unknown; }

# Bring an existing clone up to date: --ref if given; a branch is pulled; a detached
# HEAD (an install pinned to a release tag) moves to the newest release tag.
update_repo() {
  local repo="$1" from to latest
  [[ -d "$repo/.git" ]] || die "$repo is not a git clone; reinstall with the one-line installer instead"
  from="$(describe "$repo")"
  git -C "$repo" fetch --quiet --tags --force origin
  if [[ -n "$ref_opt" ]]; then
    git -C "$repo" -c advice.detachedHead=false checkout --quiet "$ref_opt"
  elif ! git -C "$repo" symbolic-ref -q HEAD >/dev/null; then
    latest="$(git -C "$repo" tag -l 'v[0-9]*' --sort=-v:refname | awk 'NR == 1')"
    [[ -n "$latest" ]] && git -C "$repo" -c advice.detachedHead=false checkout --quiet "$latest"
  fi
  if git -C "$repo" symbolic-ref -q HEAD >/dev/null; then
    git -C "$repo" pull --quiet --ff-only origin "$(git -C "$repo" branch --show-current)"
  fi
  to="$(describe "$repo")"
  if [[ "$from" == "$to" ]]; then ok "Cuadrilla is up to date ($to)"; else ok "Cuadrilla updated: $from → $to"; fi
}

# --- Locate the source files (local clone or fetch) -------------------------
script_dir=""
if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]; then
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

if [[ -n "$script_dir" && -d "$script_dir/agents" ]]; then
  src="$script_dir"
  [[ "$action" == "update" ]] && update_repo "$src"
else
  command -v git >/dev/null || die "git is required"
  if [[ -d "$CLONE_DIR/.git" && "$action" == "update" ]]; then
    update_repo "$CLONE_DIR"
  elif [[ -d "$CLONE_DIR/.git" ]]; then
    info "Updating $CLONE_DIR ($REF)"
    git -C "$CLONE_DIR" fetch --quiet --tags --force origin
    git -C "$CLONE_DIR" checkout --quiet "$REF"
    # A tag leaves HEAD detached and has nothing to pull; only branches are updated.
    if git -C "$CLONE_DIR" symbolic-ref -q HEAD >/dev/null; then
      git -C "$CLONE_DIR" pull --quiet --ff-only origin "$REF"
    fi
  else
    info "Cloning $REPO_URL ($REF) into $CLONE_DIR"
    mkdir -p "$(dirname "$CLONE_DIR")"
    git -c advice.detachedHead=false clone --quiet --branch "$REF" "$REPO_URL" "$CLONE_DIR"
  fi
  src="$CLONE_DIR"
fi

# After an update, the installer itself may have changed: run the updated one.
if [[ "$action" == "update" ]]; then
  exec bash "$src/install.sh" ${passthru[@]+"${passthru[@]}"}
fi

# --- Resolve target and format -------------------------------------------------
if [[ "$scope" == "global" ]]; then
  target="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
  [[ -z "$link_mode" ]] && link_mode="link"
else
  target="$(cd "${project_dir:-.}" && pwd)/.opencode"
  [[ -z "$link_mode" ]] && link_mode="copy"
fi

# Major version of an OpenCode binary on PATH, or nothing.
opencode_major() {
  command -v "$1" >/dev/null 2>&1 || return 0
  local out
  if command -v timeout >/dev/null 2>&1; then
    out="$(timeout 10 "$1" --version 2>/dev/null || true)"
  else
    out="$("$1" --version 2>/dev/null || true)"
  fi
  printf '%s\n' "$out" | grep -oE '[0-9]+\.[0-9]+' | awk 'NR == 1 { split($0, v, "."); print v[1] }'
}

if [[ "$format" == "auto" && "$action" == "install" ]]; then
  has_v1=false has_v2=false
  for bin in opencode opencode2; do
    case "$(opencode_major "$bin")" in
      "") ;;
      0|1) has_v1=true ;;
      *) has_v2=true ;;
    esac
  done
  if $has_v2 && ! $has_v1; then format="v2"; else format="v1"; fi
  if ! $has_v1 && ! $has_v2; then
    info "OpenCode not found on PATH: installing the v1 format, which OpenCode 1.x and 2.x both read"
  fi
fi

agents_src="$src/agents"
[[ "$format" == "v2" ]] && agents_src="$src/dist/v2/agents"
[[ "$action" != "install" || -d "$agents_src" ]] || die "$agents_src not found: this checkout has no $format agents"

sha() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  else shasum -a 256 "$1" | awk '{print $1}'; fi
}

# Previous install, from the manifest: "<sha256>  <kind>/<name>" lines.
# (Plain strings, not associative arrays: macOS ships bash 3.2.)
recorded=""
if [[ -f "$target/$MANIFEST" ]]; then recorded="$(grep -v '^#' "$target/$MANIFEST" || true)"; fi
recorded_hash() { printf '%s\n' "$recorded" | awk -v rel="$1" '$2 == rel { print $1; exit }'; }
recorded_paths() { printf '%s\n' "$recorded" | awk 'NF == 2 { print $2 }'; }

installed=$'\n'
is_installed() { [[ "$installed" == *$'\n'"$1"$'\n'* ]]; }
mark_installed() { installed+="$1"$'\n'; }

stamp="$(date +%Y%m%d%H%M%S)"
count=0

# --- Uninstall ------------------------------------------------------------------
if [[ "$action" == "uninstall" ]]; then
  names=()
  for f in "$src/agents"/*.md "$src/dist/v2/agents"/*.md; do [[ -e "$f" ]] && names+=("agents/$(basename "$f")"); done
  for f in "$src/commands"/*.md; do [[ -e "$f" ]] && names+=("commands/$(basename "$f")"); done
  while IFS= read -r rel; do [[ -n "$rel" ]] && names+=("$rel"); done < <(recorded_paths)
  for rel in ${names[@]+"${names[@]}"}; do
    is_installed "$rel" && continue
    mark_installed "$rel"
    if [[ -L "$target/$rel" || -f "$target/$rel" ]]; then rm -f "$target/$rel"; ok "removed $rel"; count=$((count+1)); fi
  done
  rm -f "$target/$MANIFEST"
  if [[ "$scope" == "global" && -L "$BIN_DIR/cuadrilla" ]]; then rm -f "$BIN_DIR/cuadrilla"; ok "removed $BIN_DIR/cuadrilla"; fi
  ok "Uninstalled $count files from $target"
  exit 0
fi

# --- Install --------------------------------------------------------------------
for kind in agents commands; do
  dir="$agents_src"
  [[ "$kind" == "commands" ]] && dir="$src/commands"
  mkdir -p "$target/$kind"
  for file in "$dir"/*.md; do
    [[ -e "$file" ]] || continue
    rel="$kind/$(basename "$file")"
    dest="$target/$rel"
    mark_installed "$rel"

    # Back up anything that isn't ours: not a symlink, not what we installed last time
    # (manifest hash), and not identical to the new file.
    if [[ -e "$dest" && ! -L "$dest" ]] && ! cmp -s "$file" "$dest" \
       && [[ "$(sha "$dest")" != "$(recorded_hash "$rel")" ]]; then
      mv "$dest" "$dest.bak.$stamp"
      info "backed up existing $rel → $(basename "$rel").bak.$stamp"
    fi
    rm -f "$dest"
    if [[ "$link_mode" == "link" ]]; then ln -s "$file" "$dest"; else cp "$file" "$dest"; fi
    count=$((count+1))
  done
done

# Remove files a previous version installed that this one no longer ships.
while IFS= read -r rel; do
  [[ -z "$rel" ]] && continue
  is_installed "$rel" && continue
  dest="$target/$rel"
  if [[ -L "$dest" ]] || { [[ -f "$dest" ]] && [[ "$(sha "$dest")" == "$(recorded_hash "$rel")" ]]; }; then
    rm -f "$dest"; info "removed $rel (no longer part of Cuadrilla)"
  fi
done < <(recorded_paths)

{
  echo "# Cuadrilla install manifest: lets updates and uninstalls tell its files from yours."
  echo "# format: $format - source: $(describe "$src")"
  while IFS= read -r rel; do
    [[ -n "$rel" ]] && printf '%s  %s\n' "$(sha "$target/$rel")" "$rel"
  done <<< "$installed"
} > "$target/$MANIFEST"

ok "Installed $count files into $target ($link_mode, $format format, $(describe "$src"))"

# The `cuadrilla` command (global installs): a link to bin/cuadrilla in the clone.
cli_note=""
if [[ "$scope" == "global" && -f "$src/bin/cuadrilla" ]]; then
  mkdir -p "$BIN_DIR"
  if [[ -e "$BIN_DIR/cuadrilla" && ! -L "$BIN_DIR/cuadrilla" ]]; then
    info "$BIN_DIR/cuadrilla exists and isn't ours: left as is"
  else
    ln -sfn "$src/bin/cuadrilla" "$BIN_DIR/cuadrilla"
    case ":$PATH:" in
      *":$BIN_DIR:"*) cli_note="  Update later with:  cuadrilla update" ;;
      *) cli_note="  Update later with:  $BIN_DIR/cuadrilla update   (add $BIN_DIR to your PATH to type just 'cuadrilla')" ;;
    esac
  fi
fi
[[ -n "$cli_note" ]] || cli_note="  Update later with:  \"$src/install.sh\" --update${project_dir:+ --project \"$project_dir\"}"

cat <<EOF

Next steps:
  1. Restart OpenCode.
  2. Press Tab until you see the "cuadrilla" agent, then describe what you want.
  3. Try:  /cuadrilla-plan add rate limiting to the login endpoint
  4. Optional: set per-agent models — see examples/ in $src
$cli_note
EOF
