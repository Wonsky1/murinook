#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT="$REPO_ROOT/Murinook.xcodeproj"
SCHEME="Murinook"
WORK_DIR="$REPO_ROOT/work"
DERIVED_DATA="$WORK_DIR/Release/DerivedData"
OUTPUT_DIR="$WORK_DIR/releases"

if [[ ! -d "$PROJECT" ]]; then
  echo "Missing Xcode project: $PROJECT" >&2
  exit 1
fi

mkdir -p "$WORK_DIR" "$OUTPUT_DIR"

xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA" \
  -destination 'generic/platform=macOS' \
  ARCHS='arm64 x86_64' \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_IDENTITY=- \
  DEVELOPMENT_TEAM= \
  CODE_SIGN_STYLE=Manual \
  build

APP_PATH="$DERIVED_DATA/Build/Products/Release/Murinook.app"
INFO_PLIST="$APP_PATH/Contents/Info.plist"
if [[ ! -d "$APP_PATH" || ! -f "$INFO_PLIST" ]]; then
  echo "Built app or Info.plist not found: $APP_PATH" >&2
  exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :MurinookReleaseVersion' "$INFO_PLIST")"
BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST")"
SEMVER_PATTERN='^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-((0|[1-9][0-9]*|[0-9A-Za-z-]*[A-Za-z-][0-9A-Za-z-]*)(\.(0|[1-9][0-9]*|[0-9A-Za-z-]*[A-Za-z-][0-9A-Za-z-]*))*))?(\+[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?$'
if [[ ! "$VERSION" =~ $SEMVER_PATTERN ]]; then
  echo "Invalid MurinookReleaseVersion in app Info.plist: $VERSION" >&2
  exit 1
fi
if [[ -z "$BUILD_NUMBER" ]]; then
  echo "CFBundleVersion is empty in app Info.plist" >&2
  exit 1
fi

if [[ -n "${RELEASE_TAG:-}" ]]; then
  EXPECTED_VERSION="${RELEASE_TAG#v}"
  if [[ "$EXPECTED_VERSION" != "$VERSION" ]]; then
    echo "Release tag $RELEASE_TAG does not match app version $VERSION" >&2
    exit 1
  fi
fi

ARCHS="$(/usr/bin/lipo -archs "$APP_PATH/Contents/MacOS/Murinook")"
if [[ "$ARCHS" != *arm64* || "$ARCHS" != *x86_64* ]]; then
  echo "Release binary is not universal (arm64 and x86_64): $ARCHS" >&2
  exit 1
fi

/usr/bin/codesign --verify --deep --strict "$APP_PATH"

STAGE_DIR="$(/usr/bin/mktemp -d "$WORK_DIR/.Murinook-dmg-stage.XXXXXX")"
cleanup() {
  if [[ -n "${STAGE_DIR:-}" && -d "$STAGE_DIR" ]]; then
    /bin/rm -rf "$STAGE_DIR"
  fi
}
trap cleanup EXIT HUP INT TERM

/usr/bin/ditto "$APP_PATH" "$STAGE_DIR/Murinook.app"
/bin/ln -s /Applications "$STAGE_DIR/Applications"

DMG_NAME="Murinook-$VERSION-universal.dmg"
DMG_PATH="$OUTPUT_DIR/$DMG_NAME"
SUMS_PATH="$OUTPUT_DIR/SHA256SUMS"
/usr/bin/hdiutil create \
  -volname "Murinook $VERSION" \
  -srcfolder "$STAGE_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"
/usr/bin/hdiutil verify "$DMG_PATH"

(
  cd "$OUTPUT_DIR"
  /usr/bin/shasum -a 256 "$DMG_NAME" > "$SUMS_PATH.tmp"
  /bin/mv -f "$SUMS_PATH.tmp" "$SUMS_PATH"
)

echo "Packaged $DMG_PATH (build $BUILD_NUMBER)"
echo "Checksum: $SUMS_PATH"
