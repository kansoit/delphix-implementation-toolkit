#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPER_DIR="${MASKING_HELPER_SRC:-${SCRIPT_DIR}/../delphix-masking-helper}"
HELPER_TAG="${1:-v2.6.0}"

if [[ ! -d "$HELPER_DIR/.git" ]]; then
  echo "ERROR: delphix-masking-helper Git repository not found: $HELPER_DIR" >&2
  exit 1
fi

if [[ -n "$(git -C "$HELPER_DIR" status --short)" ]]; then
  echo "ERROR: delphix-masking-helper has local changes:" >&2
  git -C "$HELPER_DIR" status --short >&2
  echo "Preserve those changes before updating; this script does not stash or delete them." >&2
  exit 1
fi

echo "Fetching tags from the masking-helper remote..."
git -C "$HELPER_DIR" fetch origin --tags

if ! git -C "$HELPER_DIR" rev-parse --verify --quiet "refs/tags/$HELPER_TAG" >/dev/null; then
  echo "ERROR: tag not found: $HELPER_TAG" >&2
  exit 1
fi

echo "Checking out $HELPER_TAG..."
git -C "$HELPER_DIR" switch --detach "$HELPER_TAG"

HELPER_VERSION="$(cd "$HELPER_DIR" && node -p "require('./package.json').version" 2>/dev/null || true)"
if [[ -z "$HELPER_VERSION" ]]; then
  echo "ERROR: could not read package.json version from $HELPER_DIR" >&2
  exit 1
fi

echo "Masking Helper tag: $HELPER_TAG"
echo "Masking Helper package version: $HELPER_VERSION"

if [[ "$HELPER_TAG" == v* && "$HELPER_VERSION" != "${HELPER_TAG#v}" ]]; then
  echo "WARNING: Git tag and package.json version differ." >&2
fi

echo "Preparing the OCI build context..."
"$SCRIPT_DIR/prepare-build-context.sh"

echo "Build context ready. Build the image with:"
echo "  podman build --pull=always --tag localhost/delphix-implementation-toolkit:${HELPER_VERSION} --file Dockerfile .build-context"
echo "  docker build --pull --tag delphix-implementation-toolkit:${HELPER_VERSION} --file Dockerfile .build-context"
