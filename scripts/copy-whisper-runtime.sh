#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WHISPER_BUILD_DIR="${WHISPER_BUILD_DIR:-$ROOT_DIR/Vendor/whisper.cpp/build}"
WHISPER_CLI="${WHISPER_CLI_PATH:-$WHISPER_BUILD_DIR/bin/whisper-cli}"
DESTINATION_DIR="${TARGET_BUILD_DIR:?}/${UNLOCALIZED_RESOURCES_FOLDER_PATH:?}/whisper"
DESTINATION="$DESTINATION_DIR/whisper-cli"

if [[ ! -x "$WHISPER_CLI" ]]; then
  echo "warning: whisper-cli was not found at $WHISPER_CLI"
  echo "warning: Run scripts/build-whisper-cpp.sh to bundle local Whisper support."
  exit 0
fi

mkdir -p "$DESTINATION_DIR"
cp "$WHISPER_CLI" "$DESTINATION"
chmod 755 "$DESTINATION"

DYLIB_DIRS=(
  "$WHISPER_BUILD_DIR/src"
  "$WHISPER_BUILD_DIR/ggml/src"
  "$WHISPER_BUILD_DIR/ggml/src/ggml-blas"
  "$WHISPER_BUILD_DIR/ggml/src/ggml-cpu"
  "$WHISPER_BUILD_DIR/ggml/src/ggml-metal"
)

for dylib_dir in "${DYLIB_DIRS[@]}"; do
  if [[ -d "$dylib_dir" ]]; then
    find "$dylib_dir" -maxdepth 1 \( -name "*.dylib" -o -name "*.dylib.*" \) -print0 |
      while IFS= read -r -d '' dylib; do
        cp -P "$dylib" "$DESTINATION_DIR/"
      done
  fi
done

if command -v install_name_tool >/dev/null 2>&1; then
  while IFS= read -r rpath; do
    install_name_tool -delete_rpath "$rpath" "$DESTINATION" 2>/dev/null || true
  done < <(otool -l "$DESTINATION" | awk '/cmd LC_RPATH/{getline; getline; print $2}')

  install_name_tool -add_rpath "@executable_path" "$DESTINATION" 2>/dev/null || true

  find "$DESTINATION_DIR" -maxdepth 1 -type f -name "*.dylib*" -print0 |
    while IFS= read -r -d '' dylib; do
      install_name_tool -add_rpath "@loader_path" "$dylib" 2>/dev/null || true
    done
fi

echo "Copied whisper-cli to $DESTINATION"
