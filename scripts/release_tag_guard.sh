#!/usr/bin/env bash
# Create the release tag for a version, or keep an existing one.
#
# Extracted verbatim from release.yml's tag-and-release "Create and push tag"
# step so the decision has somewhere to be tested.
#
# Usage: release_tag_guard.sh <version> <commit-sha> [remote]

set -euo pipefail

VERSION="${1:-}"
COMMIT="${2:-}"
REMOTE="${3:-origin}"
VTAG="v${VERSION}"

if git ls-remote --exit-code --tags "$REMOTE" "refs/tags/${VTAG}" >/dev/null 2>&1; then
    echo "Tag ${VTAG} already exists; leaving it in place."
else
    echo "Tagging ${VTAG} at ${COMMIT}"
    git tag --annotate --message="jac ${VERSION}" "$VTAG" "$COMMIT"
    git push "$REMOTE" "refs/tags/${VTAG}"
fi
