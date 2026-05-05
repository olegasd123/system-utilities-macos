#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
APP_NAME="System Monitor"
EXECUTABLE_NAME="SystemMonitor"
CONFIGURATION="${CONFIGURATION:-release}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
APP_PATH="$ROOT_DIR/dist/$APP_NAME.app"
CONTENTS_PATH="$APP_PATH/Contents"
MACOS_PATH="$CONTENTS_PATH/MacOS"
RESOURCES_PATH="$CONTENTS_PATH/Resources"
BUILD_HOME="$ROOT_DIR/.build/package-home"
MODULE_CACHE_PATH="$ROOT_DIR/.build/module-cache"
DEFAULT_ICON_PATH="$ROOT_DIR/Packaging/AppIcon.icns"

cd "$ROOT_DIR"

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
mkdir -p "$MACOS_PATH" "$RESOURCES_PATH"

cp "$ROOT_DIR/.build/$CONFIGURATION/$EXECUTABLE_NAME" "$MACOS_PATH/$EXECUTABLE_NAME"
cp "$ROOT_DIR/Packaging/Info.plist" "$CONTENTS_PATH/Info.plist"

ICON_PATH="${APP_ICON_PATH:-$DEFAULT_ICON_PATH}"

if [ -f "$ICON_PATH" ]; then
    cp "$ICON_PATH" "$RESOURCES_PATH/AppIcon.icns"
    /usr/libexec/PlistBuddy -c "Delete :CFBundleIconFile" "$CONTENTS_PATH/Info.plist" 2> /dev/null || true
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$CONTENTS_PATH/Info.plist"
fi

if [ "$SIGN_IDENTITY" = "-" ]; then
    codesign --force --sign - "$APP_PATH"
else
    codesign --force \
        --sign "$SIGN_IDENTITY" \
        --options runtime \
        --timestamp \
        "$APP_PATH"
fi

codesign --verify --deep --strict "$APP_PATH"

echo "$APP_PATH"
