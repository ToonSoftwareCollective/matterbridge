#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
APP_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
cd "$APP_DIR"

VERSION=$(tr -d '[:space:]' <version.txt)
fail() { echo "Matter Bridge-controle mislukt: $*" >&2; exit 1; }

grep -q "^version=$VERSION$" toonstore.cfg || fail "versie in toonstore.cfg wijkt af"
grep -q "<version>$VERSION</version>" ToonRepo-entry.xml || fail "versie in ToonRepo-entry.xml wijkt af"
grep -q '^internet=false$' toonstore.cfg || fail "internet moet uitgeschakeld zijn"

for path in MatterbridgeApp.qml MatterBridgeTile.qml MatterBridgeScreen.qml matterbridge.sh \
    qmldir toonstore.cfg ToonRepo-entry.xml version.txt README.md \
    description/description.txt drawables/MatterBridgeIcon.svg \
    service/toon-matter-service.sh service/toon-plugin/package.json \
    service/toon-plugin/dist/module.js \
    vendor/toon-node-runtime.complete.tar.gz \
    vendor/toon-matter-app-busybox.complete.tar.gz \
    vendor/icudt76l.dat \
    docs/images/matterbridge_screenshot_1.png \
    docs/images/matterbridge_screenshot_2.png \
    docs/images/matterbridge_screenshot_3.png
do
    [ -s "$path" ] || fail "vereist bestand ontbreekt of is leeg: $path"
done

grep -q 'nl.toon.matter-bridge/preferences-v1' MatterbridgeApp.qml || fail "voorkeurenschema ontbreekt"
grep -q 'matter_eligible === true' MatterbridgeApp.qml || fail "filter voor volledig bekende apparaten ontbreekt"
grep -q 'external-matterbridge' MatterbridgeApp.qml || fail "TSC-installatieaanvraag ontbreekt"
grep -q '<screenshots>3</screenshots>' ToonRepo-entry.xml || fail "catalogus verwacht drie screenshots"

EXPECTED_RUNTIME=9f6de98d07d021110d69861d842d28e87cd0c4307917dbe72a2a82efe9b07b62
EXPECTED_APP=8e0ab976ec84421a0698c6824981ea93b171731db53c3bcaddcceb1148e83f61
EXPECTED_ICU=c2a3fd74d2d7634ddae740c64ed90a714cd22f90538f563197155128c50b7daf
hash_file() { sha256sum "$1" 2>/dev/null | awk '{print $1}' || shasum -a 256 "$1" | awk '{print $1}'; }
[ "$(hash_file vendor/toon-node-runtime.complete.tar.gz)" = "$EXPECTED_RUNTIME" ] || fail "Node-runtime heeft een onverwachte checksum"
[ "$(hash_file vendor/toon-matter-app-busybox.complete.tar.gz)" = "$EXPECTED_APP" ] || fail "Matterbridge-bundle heeft een onverwachte checksum"
[ "$(hash_file vendor/icudt76l.dat)" = "$EXPECTED_ICU" ] || fail "ICU-gegevensbestand heeft een onverwachte checksum"
grep -q -- "--passcode" service/toon-matter-service.sh || fail "service start zonder vaste koppelcode; QR-code in de app klopt dan niet"

sh -n matterbridge.sh service/toon-matter-service.sh
tar -tzf vendor/toon-node-runtime.complete.tar.gz >/dev/null
tar -tzf vendor/toon-matter-app-busybox.complete.tar.gz >/dev/null

if rg -n --hidden --glob '!vendor/**' --glob '!docs/images/**' \
    '(BEGIN (RSA|OPENSSH|EC) PRIVATE KEY|192\.168\.|password["'"']?[[:space:]]*[:=][[:space:]]*["'"'][^"'"']+)' . >/dev/null 2>&1
then
    fail "mogelijk geheim, lokaal adres of wachtwoord gevonden"
fi

echo "Matter Bridge $VERSION is intern consistent"
