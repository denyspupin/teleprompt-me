#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR_DIR="$ROOT_DIR/Vendor"
WHISPER_DIR="$VENDOR_DIR/whisper.cpp"
WHISPER_REF="${WHISPER_CPP_REF:-99613cb720b65036237d44b52f753b51f75c2797}"
MACOS_MIN_OS_VERSION="${MACOS_MIN_OS_VERSION:-26.0}"
BUILD_DIR="$WHISPER_DIR/build-macos-arm64"
FRAMEWORK_DIR="$BUILD_DIR/framework/whisper.framework"
FRAMEWORK_VERSION_DIR="$FRAMEWORK_DIR/Versions/A"
FRAMEWORK_PATH="$WHISPER_DIR/build-apple/whisper.xcframework"

if ! command -v git >/dev/null 2>&1; then
  echo "git is required."
  exit 1
fi

if ! command -v cmake >/dev/null 2>&1; then
  echo "cmake is required. Install it with Homebrew or from cmake.org."
  exit 1
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild is required. Install Xcode and Xcode Command Line Tools."
  exit 1
fi

if ! command -v libtool >/dev/null 2>&1; then
  echo "libtool is required. Install Xcode Command Line Tools."
  exit 1
fi

mkdir -p "$VENDOR_DIR"

if [[ ! -d "$WHISPER_DIR/.git" ]]; then
  echo "Cloning whisper.cpp..."
  git clone https://github.com/ggml-org/whisper.cpp.git "$WHISPER_DIR"
fi

echo "Checking out whisper.cpp $WHISPER_REF..."
git -C "$WHISPER_DIR" fetch --tags origin
git -C "$WHISPER_DIR" checkout "$WHISPER_REF"

cd "$WHISPER_DIR"

echo "Cleaning previous Apple framework output..."
rm -rf "$BUILD_DIR" build-apple

echo "Configuring whisper.cpp for macOS ${MACOS_MIN_OS_VERSION}+ arm64..."
cmake -B "$BUILD_DIR" -G Xcode \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_OSX_DEPLOYMENT_TARGET="$MACOS_MIN_OS_VERSION" \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_XCODE_ATTRIBUTE_ARCHS=arm64 \
  -DCMAKE_XCODE_ATTRIBUTE_ONLY_ACTIVE_ARCH=NO \
  -DCMAKE_XCODE_ATTRIBUTE_SUPPORTED_PLATFORMS=macosx \
  -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED=NO \
  -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY="" \
  -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED=NO \
  -DCMAKE_XCODE_ATTRIBUTE_DEBUG_INFORMATION_FORMAT="dwarf-with-dsym" \
  -DCMAKE_XCODE_ATTRIBUTE_DEVELOPMENT_TEAM=ggml \
  -DBUILD_SHARED_LIBS=OFF \
  -DWHISPER_BUILD_EXAMPLES=OFF \
  -DWHISPER_BUILD_TESTS=OFF \
  -DWHISPER_BUILD_SERVER=OFF \
  -DWHISPER_COREML=ON \
  -DWHISPER_COREML_ALLOW_FALLBACK=ON \
  -DGGML_METAL=ON \
  -DGGML_METAL_EMBED_LIBRARY=ON \
  -DGGML_METAL_USE_BF16=ON \
  -DGGML_BLAS_DEFAULT=ON \
  -DGGML_NATIVE=OFF \
  -DGGML_OPENMP=OFF \
  -DCMAKE_C_FLAGS="-Wno-macro-redefined -Wno-shorten-64-to-32 -Wno-unused-command-line-argument -g" \
  -DCMAKE_CXX_FLAGS="-Wno-macro-redefined -Wno-shorten-64-to-32 -Wno-unused-command-line-argument -g" \
  -S .

echo "Building whisper.cpp static libraries..."
cmake --build "$BUILD_DIR" --config Release -- -quiet

echo "Creating macOS framework structure..."
mkdir -p "$FRAMEWORK_VERSION_DIR/Headers" "$FRAMEWORK_VERSION_DIR/Modules" "$FRAMEWORK_VERSION_DIR/Resources"
ln -sf A "$FRAMEWORK_DIR/Versions/Current"
ln -sf Versions/Current/Headers "$FRAMEWORK_DIR/Headers"
ln -sf Versions/Current/Modules "$FRAMEWORK_DIR/Modules"
ln -sf Versions/Current/Resources "$FRAMEWORK_DIR/Resources"
ln -sf Versions/Current/whisper "$FRAMEWORK_DIR/whisper"

cp include/whisper.h "$FRAMEWORK_VERSION_DIR/Headers/"
cp ggml/include/ggml.h "$FRAMEWORK_VERSION_DIR/Headers/"
cp ggml/include/ggml-alloc.h "$FRAMEWORK_VERSION_DIR/Headers/"
cp ggml/include/ggml-backend.h "$FRAMEWORK_VERSION_DIR/Headers/"
cp ggml/include/ggml-metal.h "$FRAMEWORK_VERSION_DIR/Headers/"
cp ggml/include/ggml-cpu.h "$FRAMEWORK_VERSION_DIR/Headers/"
cp ggml/include/ggml-blas.h "$FRAMEWORK_VERSION_DIR/Headers/"
cp ggml/include/gguf.h "$FRAMEWORK_VERSION_DIR/Headers/"

cat > "$FRAMEWORK_VERSION_DIR/Modules/module.modulemap" <<'EOF'
framework module whisper {
    header "whisper.h"
    header "ggml.h"
    header "ggml-alloc.h"
    header "ggml-backend.h"
    header "ggml-metal.h"
    header "ggml-cpu.h"
    header "ggml-blas.h"
    header "gguf.h"

    link "c++"
    link framework "Accelerate"
    link framework "Metal"
    link framework "Foundation"

    export *
}
EOF

cat > "$FRAMEWORK_VERSION_DIR/Resources/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>whisper</string>
    <key>CFBundleIdentifier</key>
    <string>org.ggml.whisper</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>whisper</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>MinimumOSVersion</key>
    <string>${MACOS_MIN_OS_VERSION}</string>
    <key>CFBundleSupportedPlatforms</key>
    <array>
        <string>MacOSX</string>
    </array>
    <key>DTPlatformName</key>
    <string>macosx</string>
    <key>DTSDKName</key>
    <string>macosx${MACOS_MIN_OS_VERSION}</string>
</dict>
</plist>
EOF

echo "Linking dynamic framework binary..."
TEMP_DIR="$BUILD_DIR/temp"
mkdir -p "$TEMP_DIR"
libtool -static -o "$TEMP_DIR/combined.a" \
  "$BUILD_DIR/src/Release/libwhisper.a" \
  "$BUILD_DIR/src/Release/libwhisper.coreml.a" \
  "$BUILD_DIR/ggml/src/Release/libggml.a" \
  "$BUILD_DIR/ggml/src/Release/libggml-base.a" \
  "$BUILD_DIR/ggml/src/Release/libggml-cpu.a" \
  "$BUILD_DIR/ggml/src/ggml-metal/Release/libggml-metal.a" \
  "$BUILD_DIR/ggml/src/ggml-blas/Release/libggml-blas.a" 2>/dev/null

xcrun -sdk macosx clang++ -dynamiclib \
  -isysroot "$(xcrun --sdk macosx --show-sdk-path)" \
  -arch arm64 \
  -mmacosx-version-min="$MACOS_MIN_OS_VERSION" \
  -Wl,-force_load,"$TEMP_DIR/combined.a" \
  -framework Foundation \
  -framework Metal \
  -framework Accelerate \
  -framework CoreML \
  -install_name "@rpath/whisper.framework/Versions/Current/whisper" \
  -o "$FRAMEWORK_VERSION_DIR/whisper"

mkdir -p "$BUILD_DIR/dSYMs"
xcrun dsymutil "$FRAMEWORK_VERSION_DIR/whisper" -o "$BUILD_DIR/dSYMs/whisper.dSYM"
xcrun strip -S "$FRAMEWORK_VERSION_DIR/whisper" -o "$TEMP_DIR/stripped_whisper"
mv "$TEMP_DIR/stripped_whisper" "$FRAMEWORK_VERSION_DIR/whisper"
rm -rf "$TEMP_DIR"

echo "Creating macOS arm64 XCFramework..."
mkdir -p build-apple
xcodebuild -create-xcframework \
  -framework "$FRAMEWORK_DIR" \
  -debug-symbols "$BUILD_DIR/dSYMs/whisper.dSYM" \
  -output "$FRAMEWORK_PATH"

echo
echo "Built whisper.cpp framework:"
echo "$FRAMEWORK_PATH"
