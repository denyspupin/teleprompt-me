#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/TelepromptMe.xcodeproj"
SCHEME="TelepromptMe"
APP_NAME="TelepromptMe"
BUILD_DIR="$ROOT_DIR/build/distribution"
ARCHIVE_PATH="$BUILD_DIR/$APP_NAME.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"
DIST_PATH="$BUILD_DIR/dist"
EXPORT_OPTIONS_PATH="$BUILD_DIR/ExportOptions.plist"
MODE="${1:-developer-id}"
EXPORT_SUBDIR="$MODE"
EXPORT_PATH="$EXPORT_PATH/$EXPORT_SUBDIR"
ZIP_PATH="$DIST_PATH/$APP_NAME-$MODE-macOS.zip"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild is required."
  exit 1
fi

if ! command -v ditto >/dev/null 2>&1; then
  echo "ditto is required."
  exit 1
fi

APPLE_TEAM_ID="${APPLE_TEAM_ID:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"

if [[ "$MODE" != "developer-id" && "$MODE" != "unsigned" ]]; then
  echo "Usage: ./scripts/package-macos.sh [developer-id|unsigned]"
  exit 1
fi

rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH" "$DIST_PATH"
mkdir -p "$BUILD_DIR" "$DIST_PATH"

echo "Archiving $APP_NAME..."
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "generic/platform=macOS" \
  ONLY_ACTIVE_ARCH=YES \
  ARCHS=arm64 \
  -archivePath "$ARCHIVE_PATH" \
  archive

if [[ "$MODE" == "developer-id" ]]; then
  if [[ -z "$APPLE_TEAM_ID" ]]; then
    echo "Set APPLE_TEAM_ID to your Apple Developer Team ID."
    exit 1
  fi

  cat > "$EXPORT_OPTIONS_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>destination</key>
  <string>export</string>
  <key>method</key>
  <string>developer-id</string>
  <key>signingStyle</key>
  <string>automatic</string>
  <key>stripSwiftSymbols</key>
  <true/>
  <key>teamID</key>
  <string>${APPLE_TEAM_ID}</string>
</dict>
</plist>
EOF

  echo "Exporting Developer ID app..."
  xcodebuild \
    -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS_PATH" \
    -exportPath "$EXPORT_PATH"

  APP_PATH="$EXPORT_PATH/$APP_NAME.app"

  if [[ ! -d "$APP_PATH" ]]; then
    echo "Export did not produce $APP_PATH"
    exit 1
  fi
else
  APP_PATH="$ARCHIVE_PATH/Products/Applications/$APP_NAME.app"

  if [[ ! -d "$APP_PATH" ]]; then
    echo "Archive did not produce $APP_PATH"
    exit 1
  fi
fi

echo "Creating zip..."
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

if [[ "$MODE" == "developer-id" && -n "$NOTARY_PROFILE" ]]; then
  if ! command -v xcrun >/dev/null 2>&1; then
    echo "xcrun is required for notarization."
    exit 1
  fi

  echo "Submitting for notarization..."
  xcrun notarytool submit "$ZIP_PATH" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait

  echo "Stapling notarization ticket..."
  xcrun stapler staple "$APP_PATH"

  echo "Rebuilding zip with stapled app..."
  ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
fi

echo
echo "Done."
echo "Mode: $MODE"
echo "App: $APP_PATH"
echo "Zip: $ZIP_PATH"
