#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAGE_DIR="${SCRIPT_DIR}/.build-context"

MASKING_HELPER_SRC="${MASKING_HELPER_SRC:-${SCRIPT_DIR}/../delphix-masking-helper}"
INSTALL_REPORT_SRC="${INSTALL_REPORT_SRC:-${SCRIPT_DIR}/../delphix_install_report}"
MASKING_DEVKIT_SRC="${MASKING_DEVKIT_SRC:-${SCRIPT_DIR}/../Masking_Devkit_23.0.0}"
DCT_TOOLKIT_SRC="${DCT_TOOLKIT_SRC:-${SCRIPT_DIR}/vendor/dct-toolkit}"

for required in "$MASKING_HELPER_SRC" "$INSTALL_REPORT_SRC" "$MASKING_DEVKIT_SRC" "$DCT_TOOLKIT_SRC"; do
  [[ -e "$required" ]] || { echo "ERROR: path not found: $required" >&2; exit 1; }
done

copy_tree() {
  local source="$1"
  local destination="$2"
  mkdir -p "$destination"
  tar -C "$source" \
    --exclude=.git \
    --exclude=node_modules \
    --exclude=frontend/node_modules \
    --exclude=frontend/dist \
    --exclude='db/*.db' \
    --exclude='db/*.db-shm' \
    --exclude='db/*.db-wal' \
    --exclude=test-files \
    -cf - . | tar -C "$destination" -xf -
}

rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR"

copy_tree "$MASKING_HELPER_SRC" "$STAGE_DIR/delphix-masking-helper"
copy_tree "$INSTALL_REPORT_SRC" "$STAGE_DIR/delphix_install_report"
install -m 0755 "$DCT_TOOLKIT_SRC" "$STAGE_DIR/dct-toolkit"

LIB_SOURCE="$MASKING_DEVKIT_SRC/sdkTools/lib"
LIB_DEST="$STAGE_DIR/delphix-masking-helper/lib"
mkdir -p "$LIB_DEST"

required_jars=(
  ant-1.10.13.jar
  commons-codec-1.11.jar
  commons-compiler-3.1.6.jar
  commons-lang-2.6.jar
  delphix-algorithm-plugin-2026.5.0-FINAL.jar
  failureaccess-1.0.3.jar
  guava-33.6.0-jre.jar
  jackson-annotations-2.21.jar
  jackson-core-2.21.5.jar
  jackson-databind-2.21.5.jar
  jackson-datatype-jdk8-2.21.5.jar
  jackson-datatype-jsr310-2.21.5.jar
  jackson-module-jsonSchema-2.21.5.jar
  janino-3.1.6.jar
  masking-extensibility-api-2026.5.0-FINAL.jar
)

for jar in "${required_jars[@]}"; do
  [[ -f "$LIB_SOURCE/$jar" ]] || {
    echo "ERROR: required Devkit library not found: $LIB_SOURCE/$jar" >&2
    exit 1
  }
  install -m 0644 "$LIB_SOURCE/$jar" "$LIB_DEST/$jar"
done

echo "Build context prepared at: $STAGE_DIR"
du -sh "$STAGE_DIR"
