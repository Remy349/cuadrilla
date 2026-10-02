#!/usr/bin/env bash
# Tag a version listed in CHANGELOG.md and publish its GitHub Release. Safe to re-run.
#
#   scripts/release.sh                         # the version at the top of CHANGELOG.md, at HEAD
#   scripts/release.sh v0.1.0 a03ab80          # an older version at its commit (maintainer, locally)
#   add --dry-run to only print what would happen
#
# With no arguments the top "## " heading decides: "## v1.2.3 — 2026-10-02" releases
# v1.2.3; "## Unreleased" does nothing. An existing tag is never moved.
# CI runs it on every push to main (see .github/workflows/validate.yml). Backfills of older
# commits must run locally with your own credentials: GITHUB_TOKEN can't tag them.
# Needs: git with push access; `gh` + GH_TOKEN to create the GitHub Release.
set -euo pipefail

dry_run=false
args=()
for arg in "$@"; do
  if [[ "$arg" == "--dry-run" ]]; then dry_run=true; else args+=("$arg"); fi
done
version="${args[0]:-}"
ref="${args[1]:-HEAD}"
changelog="CHANGELOG.md"

top="$(grep -m1 '^## ' "$changelog" || true)"
top_version=""
[[ "$top" =~ ^##\ (v[0-9]+\.[0-9]+\.[0-9]+)([[:space:]]|$) ]] && top_version="${BASH_REMATCH[1]}"
if [[ -z "$version" ]]; then
  if [[ -z "$top_version" ]]; then
    echo "Top of $changelog is '${top:-<none>}': nothing to release."
    exit 0
  fi
  version="$top_version"
fi
# Only the newest version may become "Latest" (GitHub marks every new release Latest by default).
latest=false
[[ "$version" == "$top_version" ]] && latest=true
[[ "$version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Invalid version '$version' (expected vX.Y.Z)" >&2; exit 1; }

# Release notes: the lines under "## <version>" up to the next heading.
heading="$(grep -m1 -E "^## ${version//./\\.}([[:space:]]|$)" "$changelog" || true)"
[[ -n "$heading" ]] || { echo "$version has no entry in $changelog" >&2; exit 1; }
notes="$(awk -v h="$heading" '$0 == h {on=1; next} on && /^## / {exit} on' "$changelog")"

publish() {
  gh release create "$version" --title "$version" --notes "$notes" --verify-tag --latest="$latest"
}

if git rev-parse -q --verify "refs/tags/$version" >/dev/null; then
  # Tagged by an earlier run that failed before publishing: finish the job.
  if ! $dry_run && ! gh release view "$version" >/dev/null 2>&1; then
    echo "$version is tagged but has no GitHub Release: publishing it."
    publish
    exit 0
  fi
  echo "$version is already released: nothing to do."
  exit 0
fi
commit="$(git rev-parse --verify "$ref^{commit}")"

echo "Releasing $version at ${commit:0:7} (latest: $latest)"
printf '%s\n' "$notes"
if $dry_run; then
  echo "(dry run: no tag or release created)"
  exit 0
fi

# In CI the tagger is the Actions bot; locally, your own git identity.
identity=()
[[ -n "${GITHUB_ACTIONS:-}" ]] && identity=(-c user.name="github-actions[bot]" \
  -c user.email="41898282+github-actions[bot]@users.noreply.github.com")
git "${identity[@]}" tag -a "$version" -m "$version" "$commit"
git push origin "refs/tags/$version"
publish
