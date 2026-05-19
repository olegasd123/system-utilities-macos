#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
APP_NAME="System Monitor"
EXECUTABLE_NAME="SystemMonitor"
APP_EXECUTABLE_NAME="System Monitor"
CONFIGURATION="${CONFIGURATION:-release}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
APP_PATH="$ROOT_DIR/dist/$APP_NAME.app"
CONTENTS_PATH="$APP_PATH/Contents"
MACOS_PATH="$CONTENTS_PATH/MacOS"
RESOURCES_PATH="$CONTENTS_PATH/Resources"
FRAMEWORKS_PATH="$CONTENTS_PATH/Frameworks"
BUILD_HOME="$ROOT_DIR/.build/package-home"
MODULE_CACHE_PATH="$ROOT_DIR/.build/module-cache"
DEFAULT_ICON_PATH="$ROOT_DIR/Packaging/AppIcon.icns"
ENTITLEMENTS_PATH="$ROOT_DIR/Packaging/SystemMonitor.entitlements"
VERSION_FILE="$ROOT_DIR/VERSION"

cd "$ROOT_DIR"

if [ -z "${VERSION:-}" ] && [ -f "$VERSION_FILE" ]; then
    VERSION=$(sed -n '1p' "$VERSION_FILE" | tr -d '[:space:]')
fi

if [ -z "${BUILD_NUMBER:-}" ] && [ -n "${VERSION:-}" ]; then
    BUILD_NUMBER="$VERSION"
fi

mkdir -p "$BUILD_HOME" "$MODULE_CACHE_PATH"

env \
    HOME="$BUILD_HOME" \
    CLANG_MODULE_CACHE_PATH="$MODULE_CACHE_PATH" \
    swift build \
        --disable-sandbox \
        --cache-path "$ROOT_DIR/.build/cache" \
        --scratch-path "$ROOT_DIR/.build" \
        --manifest-cache local \
        -c "$CONFIGURATION"

rm -rf "$APP_PATH"
mkdir -p "$MACOS_PATH" "$RESOURCES_PATH" "$FRAMEWORKS_PATH"

cp "$ROOT_DIR/.build/$CONFIGURATION/$EXECUTABLE_NAME" "$MACOS_PATH/$APP_EXECUTABLE_NAME"
cp "$ROOT_DIR/Packaging/Info.plist" "$CONTENTS_PATH/Info.plist"

if [ -n "${VERSION:-}" ]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$CONTENTS_PATH/Info.plist"
fi

if [ -n "${BUILD_NUMBER:-}" ]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$CONTENTS_PATH/Info.plist"
fi

if [ -n "${SPARKLE_FEED_URL:-}" ]; then
    /usr/libexec/PlistBuddy -c "Delete :SUFeedURL" "$CONTENTS_PATH/Info.plist" 2> /dev/null || true
    /usr/libexec/PlistBuddy -c "Add :SUFeedURL string $SPARKLE_FEED_URL" "$CONTENTS_PATH/Info.plist"
fi

if [ -n "${SPARKLE_PUBLIC_ED_KEY:-}" ]; then
    /usr/libexec/PlistBuddy -c "Delete :SUPublicEDKey" "$CONTENTS_PATH/Info.plist" 2> /dev/null || true
    /usr/libexec/PlistBuddy -c "Add :SUPublicEDKey string $SPARKLE_PUBLIC_ED_KEY" "$CONTENTS_PATH/Info.plist"
fi

SPARKLE_FRAMEWORK="$ROOT_DIR/.build/$CONFIGURATION/Sparkle.framework"
if [ ! -d "$SPARKLE_FRAMEWORK" ]; then
    SPARKLE_FRAMEWORK=$(find "$ROOT_DIR/.build" -path "*/Sparkle.framework" -type d | head -n 1)
fi
if [ -n "$SPARKLE_FRAMEWORK" ]; then
    ditto "$SPARKLE_FRAMEWORK" "$FRAMEWORKS_PATH/Sparkle.framework"
fi

for RESOURCE_BUNDLE in "$ROOT_DIR/.build/$CONFIGURATION"/*.bundle; do
    if [ -d "$RESOURCE_BUNDLE" ]; then
        ditto "$RESOURCE_BUNDLE/" "$RESOURCES_PATH"
    fi
done

ICON_PATH="${APP_ICON_PATH:-$DEFAULT_ICON_PATH}"

if [ -f "$ICON_PATH" ]; then
    cp "$ICON_PATH" "$RESOURCES_PATH/AppIcon.icns"
    /usr/libexec/PlistBuddy -c "Delete :CFBundleIconFile" "$CONTENTS_PATH/Info.plist" 2> /dev/null || true
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$CONTENTS_PATH/Info.plist"
fi

if [ "$SIGN_IDENTITY" = "-" ]; then
    if [ -d "$FRAMEWORKS_PATH/Sparkle.framework" ]; then
        codesign --force --deep --sign - "$FRAMEWORKS_PATH/Sparkle.framework"
    fi
    codesign --force --sign - --entitlements "$ENTITLEMENTS_PATH" "$APP_PATH"
else
    if [ -d "$FRAMEWORKS_PATH/Sparkle.framework" ]; then
        codesign --force \
            --deep \
            --sign "$SIGN_IDENTITY" \
            --options runtime \
            --timestamp \
            "$FRAMEWORKS_PATH/Sparkle.framework"
    fi
    codesign --force \
        --sign "$SIGN_IDENTITY" \
        --options runtime \
        --timestamp \
        --entitlements "$ENTITLEMENTS_PATH" \
        "$APP_PATH"
fi

codesign --verify --deep --strict "$APP_PATH"

echo "$APP_PATH"
