#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
APP_NAME="System Monitor"
DMG_PATH="${DMG_PATH:-$ROOT_DIR/dist/$APP_NAME.dmg}"

if [ ! -f "$DMG_PATH" ]; then
    echo "DMG is missing. Run scripts/make_dmg.sh first." >&2
    exit 1
fi

if [ -n "${NOTARY_PROFILE:-}" ]; then
    xcrun notarytool submit "$DMG_PATH" \
        --keychain-profile "$NOTARY_PROFILE" \
        --wait
elif [ -n "${APPLE_ID:-}" ] && [ -n "${TEAM_ID:-}" ] && [ -n "${APP_SPECIFIC_PASSWORD:-}" ]; then
    xcrun notarytool submit "$DMG_PATH" \
        --apple-id "$APPLE_ID" \
        --team-id "$TEAM_ID" \
        --password "$APP_SPECIFIC_PASSWORD" \
        --wait
else
    echo "Set NOTARY_PROFILE, or APPLE_ID, TEAM_ID, and APP_SPECIFIC_PASSWORD." >&2
    exit 1
fi

xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"

echo "$DMG_PATH"
