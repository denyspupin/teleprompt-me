#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR_DIR="$ROOT_DIR/Vendor"
WHISPER_DIR="$VENDOR_DIR/whisper.cpp"
WHISPER_REF="${WHISPER_CPP_REF:-99613cb720b65036237d44b52f753b51f75c2797}"
BUILD_DIR="$WHISPER_DIR/build"

if ! command -v git >/dev/null 2>&1; then
  echo "git is required."
  exit 1
fi

if ! command -v cmake >/dev/null 2>&1; then
  echo "cmake is required. Install it with Homebrew or from cmake.org."
  exit 1
fi

mkdir -p "$VENDOR_DIR"

if [[ ! -d "$WHISPER_DIR/.git" ]]; then
  echo "Cloning whisper.cpp..."
  git clone https://github.com/ggerganov/whisper.cpp.git "$WHISPER_DIR"
fi

echo "Checking out whisper.cpp $WHISPER_REF..."
git -C "$WHISPER_DIR" fetch --tags origin
git -C "$WHISPER_DIR" checkout "$WHISPER_REF"

echo "Configuring whisper.cpp..."
cmake -S "$WHISPER_DIR" -B "$BUILD_DIR" \
  -DCMAKE_BUILD_TYPE=Release \
  -DGGML_METAL=ON \
  -DWHISPER_BUILD_TESTS=OFF

echo "Building whisper-cli..."
cmake --build "$BUILD_DIR" --config Release --target whisper-cli --parallel

CLI_PATH="$BUILD_DIR/bin/whisper-cli"

if [[ ! -x "$CLI_PATH" ]]; then
  echo "Build did not produce executable $CLI_PATH"
  exit 1
fi

echo
echo "Built whisper.cpp CLI:"
echo "$CLI_PATH"
