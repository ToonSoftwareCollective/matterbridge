#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
APP_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
VERSION=$(tr -d '[:space:]' <"$APP_DIR/version.txt")
DIST_DIR="$APP_DIR/dist"
STAGING_DIR=$(mktemp -d "${TMPDIR:-/tmp}/matterbridge-pakket.XXXXXX")
trap 'rm -rf "$STAGING_DIR"' EXIT HUP INT TERM

"$APP_DIR/scripts/controleer.sh"

PACKAGE_DIR="$STAGING_DIR/matterbridge"
mkdir -p "$PACKAGE_DIR" "$DIST_DIR"
for path in MatterbridgeApp.qml MatterBridgeTile.qml MatterBridgeScreen.qml \
    matterbridge.sh qmldir toonstore.cfg ToonRepo-entry.xml version.txt README.md \
    LICENSE CHANGELOG.md SECURITY.md THIRD_PARTY_NOTICES.md \
    description drawables service vendor docs
do
    cp -R "$APP_DIR/$path" "$PACKAGE_DIR/"
done

ARCHIVE="$DIST_DIR/matterbridge-$VERSION.tar.gz"
COPYFILE_DISABLE=1 tar -C "$STAGING_DIR" -czf "$ARCHIVE" matterbridge
echo "$ARCHIVE"
sha256sum "$ARCHIVE" 2>/dev/null || shasum -a 256 "$ARCHIVE"
