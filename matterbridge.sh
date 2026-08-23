#!/bin/sh
set -eu

# Wordt uitgevoerd door het TSC-hulpscript nadat de QML-app
# "external-matterbridge" naar /tmp/tsc.command heeft geschreven.

APP_DIR=/qmf/qml/apps/matterbridge
SERVICE_ROOT=/mnt/data/tsc/matter-service
RUNTIME_ROOT="$SERVICE_ROOT/node-runtime-v22"
MATTER_APP_ROOT="$SERVICE_ROOT/app-v0.1.0"
HOME_ROOT="$SERVICE_ROOT/home"
SWAP_FILE="$SERVICE_ROOT/matter.swap"
SERVICE_SCRIPT="$SERVICE_ROOT/toon-matter-service.sh"
SERVICE_LINK=/qmf/bin/toon-matter-service.sh
BOOT_LINK=/etc/rc5.d/S99toon-matter
STATUS_ROOT=/var/volatile/tmp/toon-matter-bridge
PID_FILE=/var/run/toon-matter-service.pid
LOG_FILE=/var/volatile/log/toon-matter-service.log
RUNTIME_ARCHIVE="$APP_DIR/vendor/toon-node-runtime.complete.tar.gz"
MATTER_ARCHIVE="$APP_DIR/vendor/toon-matter-app-busybox.complete.tar.gz"
RUNTIME_SHA256=9f6de98d07d021110d69861d842d28e87cd0c4307917dbe72a2a82efe9b07b62
MATTER_SHA256=8e0ab976ec84421a0698c6824981ea93b171731db53c3bcaddcceb1148e83f61

fail() {
    echo "Matter Bridge-installatie mislukt: $*" >&2
    exit 1
}

verify_archive() {
    archive="$1"
    expected="$2"
    test -s "$archive" || fail "pakket ontbreekt: $archive"
    actual=$(/usr/bin/sha256sum "$archive" | awk '{print $1}')
    test "$actual" = "$expected" || fail "checksum wijkt af: $archive"
}

available_kb() {
    df -Pk /mnt/data | awk 'NR == 2 {print $4}'
}

extract_once() {
    archive="$1"
    target="$2"
    marker="$3"
    test -f "$target/$marker" && return 0

    staging="$target.install-$$"
    case "$staging" in
        /mnt/data/tsc/matter-service/*.install-*) ;;
        *) fail "onveilige installatiemap" ;;
    esac
    rm -rf "$staging"
    mkdir -p "$staging"
    if ! tar -xzf "$archive" -C "$staging"; then
        rm -rf "$staging"
        fail "uitpakken mislukt: $archive"
    fi
    test -f "$staging/$marker" || {
        rm -rf "$staging"
        fail "pakket mist $marker"
    }
    test ! -e "$target" || fail "onvolledige bestaande installatie: $target"
    mv "$staging" "$target"
}

ensure_swap() {
    if test ! -f "$SWAP_FILE"; then
        swap_temp="$SWAP_FILE.install-$$"
        dd if=/dev/zero of="$swap_temp" bs=1048576 count=160 2>/dev/null
        chmod 600 "$swap_temp"
        /sbin/mkswap "$swap_temp" >/dev/null
        mv "$swap_temp" "$SWAP_FILE"
    fi
    chmod 600 "$SWAP_FILE"
}

stop_service() {
    if test -x "$SERVICE_LINK"; then
        "$SERVICE_LINK" stop >/dev/null 2>&1 || true
    elif test -x "$SERVICE_SCRIPT"; then
        "$SERVICE_SCRIPT" stop >/dev/null 2>&1 || true
    fi
}

install_app() {
    verify_archive "$RUNTIME_ARCHIVE" "$RUNTIME_SHA256"
    verify_archive "$MATTER_ARCHIVE" "$MATTER_SHA256"
    mkdir -p "$SERVICE_ROOT" /var/volatile/log
    stop_service

    if test ! -f "$RUNTIME_ROOT/usr/bin/node" || \
       test ! -f "$MATTER_APP_ROOT/node_modules/matterbridge/bin/matterbridge.js" || \
       test ! -f "$SWAP_FILE"; then
        free_kb=$(available_kb)
        test "${free_kb:-0}" -ge 450000 || \
            fail "minimaal 450 MB vrije ruimte op /mnt/data nodig"
    fi

    extract_once "$RUNTIME_ARCHIVE" "$RUNTIME_ROOT" usr/bin/node
    extract_once "$MATTER_ARCHIVE" "$MATTER_APP_ROOT" node_modules/matterbridge/bin/matterbridge.js
    ensure_swap

    mkdir -p "$MATTER_APP_ROOT/plugins/matterbridge-toon/dist" "$HOME_ROOT"
    cp "$APP_DIR/service/toon-plugin/package.json" \
       "$APP_DIR/service/toon-plugin/matterbridge-toon.config.json" \
       "$APP_DIR/service/toon-plugin/matterbridge-toon.schema.json" \
       "$MATTER_APP_ROOT/plugins/matterbridge-toon/"
    cp "$APP_DIR/service/toon-plugin/dist/module.js" \
       "$MATTER_APP_ROOT/plugins/matterbridge-toon/dist/module.js"
    cp "$APP_DIR/service/toon-matter-service.sh" "$SERVICE_SCRIPT"
    chmod 755 "$SERVICE_SCRIPT" "$RUNTIME_ROOT/usr/bin/node"
    chmod 700 "$HOME_ROOT"

    ln -sf "$SERVICE_SCRIPT" "$SERVICE_LINK"
    ln -sf "$SERVICE_SCRIPT" "$BOOT_LINK"
    "$SERVICE_LINK" start
}

uninstall_app() {
    stop_service
    grep -q "^$SWAP_FILE " /proc/swaps && /sbin/swapoff "$SWAP_FILE" || true
    rm -f "$SERVICE_LINK" "$BOOT_LINK" "$PID_FILE" "$LOG_FILE"
    rm -rf "$STATUS_ROOT"
    if test "$SERVICE_ROOT" = /mnt/data/tsc/matter-service; then
        rm -rf "$SERVICE_ROOT"
    fi
}

case "${1:-install}" in
    uninstall) uninstall_app ;;
    install) install_app ;;
    *) echo "Gebruik: $0 {install|uninstall}" >&2; exit 2 ;;
esac
