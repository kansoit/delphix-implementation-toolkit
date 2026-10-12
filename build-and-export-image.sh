#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_TAG="${1:-}"
CONTAINER_ENGINE="${CONTAINER_ENGINE:-}"

if [[ -z "$IMAGE_TAG" ]]; then
  echo "Usage: $(basename "$0") <image-version>" >&2
  exit 2
fi

package_installed() {
  local engine="$1" package

  if command -v rpm >/dev/null 2>&1; then
    for package in "$engine"; do
      rpm -q "$package" >/dev/null 2>&1 && return 0
    done
    [[ "$engine" == docker ]] && {
      for package in docker-ce docker.io; do
        rpm -q "$package" >/dev/null 2>&1 && return 0
      done
    }
  fi

  if command -v dpkg-query >/dev/null 2>&1; then
    for package in "$engine"; do
      dpkg-query -W -f='${Status}' "$package" 2>/dev/null \
        | grep -q 'install ok installed' && return 0
    done
    [[ "$engine" == docker ]] && {
      for package in docker-ce docker.io; do
        dpkg-query -W -f='${Status}' "$package" 2>/dev/null \
          | grep -q 'install ok installed' && return 0
      done
    }
  fi

  return 1
}

if [[ -z "$CONTAINER_ENGINE" ]]; then
  if package_installed podman; then
    CONTAINER_ENGINE=podman
    ENGINE_SOURCE="installed package"
  elif package_installed docker; then
    CONTAINER_ENGINE=docker
    ENGINE_SOURCE="installed package"
  elif command -v podman >/dev/null 2>&1; then
    CONTAINER_ENGINE=podman
    ENGINE_SOURCE="available executable"
  elif command -v docker >/dev/null 2>&1; then
    CONTAINER_ENGINE=docker
    ENGINE_SOURCE="available executable"
  else
    echo "ERROR: neither podman nor docker was found." >&2
    exit 1
  fi
else
  ENGINE_SOURCE="CONTAINER_ENGINE override"
fi

CONTAINER_COMMAND=(sudo "$CONTAINER_ENGINE")

case "$CONTAINER_ENGINE" in
  podman)
    IMAGE_REFERENCE="${2:-localhost/delphix-implementation-toolkit:${IMAGE_TAG}}"
    BUILD_ARGS=(--pull=always --tag "$IMAGE_REFERENCE" --file "$SCRIPT_DIR/Dockerfile" "$SCRIPT_DIR/.build-context")
    ;;
  docker)
    IMAGE_REFERENCE="${2:-delphix-implementation-toolkit:${IMAGE_TAG}}"
    BUILD_ARGS=(--pull --tag "$IMAGE_REFERENCE" --file "$SCRIPT_DIR/Dockerfile" "$SCRIPT_DIR/.build-context")
    ;;
  *)
    echo "ERROR: unsupported CONTAINER_ENGINE: $CONTAINER_ENGINE" >&2
    echo "Use podman or docker." >&2
    exit 2
    ;;
esac

command -v sudo >/dev/null || {
  echo "ERROR: sudo not found." >&2
  exit 1
}

command -v "$CONTAINER_ENGINE" >/dev/null || {
  echo "ERROR: container engine not found: $CONTAINER_ENGINE" >&2
  exit 1
}

[[ -d "$SCRIPT_DIR/.build-context" ]] || {
  echo "ERROR: .build-context not found. Run ./prepare-build-context.sh first." >&2
  exit 1
}

echo "Building image: $IMAGE_REFERENCE"
echo "Container engine: $CONTAINER_ENGINE ($ENGINE_SOURCE, rootful via sudo)"
"${CONTAINER_COMMAND[@]}" build "${BUILD_ARGS[@]}"

printf 'IMAGE_VERSION=%s\n' "$IMAGE_TAG" > "$SCRIPT_DIR/.env"
echo "Compose version written to: $SCRIPT_DIR/.env"

OUTPUT_DIR="$SCRIPT_DIR/images"
ARCHIVE="$OUTPUT_DIR/delphix-implementation-toolkit-${IMAGE_TAG}.tar.gz"
CHECKSUM="${ARCHIVE}.sha256"
mkdir -p "$OUTPUT_DIR"

echo "Exporting image to: $ARCHIVE"
if [[ "$CONTAINER_ENGINE" == "podman" ]]; then
  "${CONTAINER_COMMAND[@]}" save --format docker-archive "$IMAGE_REFERENCE" \
    | gzip -9 -c > "$ARCHIVE"
else
  "${CONTAINER_COMMAND[@]}" save "$IMAGE_REFERENCE" \
    | gzip -9 -c > "$ARCHIVE"
fi

sha256sum "$ARCHIVE" > "$CHECKSUM"
echo "Checksum written to: $CHECKSUM"
