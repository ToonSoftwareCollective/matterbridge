#!/bin/sh

SERVICE_ROOT=/mnt/data/tsc/matter-service
RUNTIME_ROOT="$SERVICE_ROOT/node-runtime-v22"
APP_ROOT="$SERVICE_ROOT/app-v0.1.0"
MATTERBRIDGE_HOME="$SERVICE_ROOT/home"
STATUS_ROOT=/var/volatile/tmp/toon-matter-bridge
LOG_ROOT=/var/volatile/log
PID_FILE=/var/run/toon-matter-service.pid
LOG_FILE="$LOG_ROOT/toon-matter-service.log"
SWAP_FILE="$SERVICE_ROOT/matter.swap"
LOADER="$RUNTIME_ROOT/lib/ld-musl-armhf.so.1"
NODE="$RUNTIME_ROOT/usr/bin/node"
LIBRARY_PATH="$RUNTIME_ROOT/lib:$RUNTIME_ROOT/usr/lib"
MATTERBRIDGE="$APP_ROOT/node_modules/matterbridge/bin/matterbridge.js"
PLUGIN_PACKAGE="$APP_ROOT/plugins/matterbridge-toon/package.json"
PLUGIN_REGISTRY="$MATTERBRIDGE_HOME/.matterbridge/storage/.matterbridge/92cd10e6b8b068a931196d1d73a032543d5ca1a5bf445e27a1af74258254517c"

is_running() {
    test -f "$PID_FILE" && kill -0 "$(sed -n '1p' "$PID_FILE")" 2>/dev/null
}

allow_udp_rule() {
    firewall="$1"
    shift
    "$firewall" -C HCB-INPUT "$@" -j ACCEPT 2>/dev/null || \
        "$firewall" -I HCB-INPUT 1 "$@" -j ACCEPT 2>/dev/null || true
}

allow_matter_traffic() {
    allow_udp_rule /usr/sbin/iptables -i wlan0 -p udp --dport 5540
    allow_udp_rule /usr/sbin/iptables -i wlan0 -p udp --dport 5353
    allow_udp_rule /usr/sbin/iptables -i wlan0 -p udp --sport 5353
    allow_udp_rule /usr/sbin/ip6tables -i wlan0 -p udp --dport 5540
    allow_udp_rule /usr/sbin/ip6tables -i wlan0 -p udp --dport 5353
    allow_udp_rule /usr/sbin/ip6tables -i wlan0 -p udp --sport 5353
    # Matter uses IPv6 link-local traffic. Neighbour discovery is ICMPv6, so
    # blocking it prevents a controller from ever reaching UDP 5540.
    allow_udp_rule /usr/sbin/ip6tables -i wlan0 -p ipv6-icmp
}

activate_matter_swap() {
    test -r "$SWAP_FILE" || exit 1
    grep -q "^$SWAP_FILE " /proc/swaps || /sbin/swapon "$SWAP_FILE" || exit 1
}

run_matterbridge() {
    exec env \
        ICU_DATA="$RUNTIME_ROOT/usr/share/icu/76.1" \
        NODE_OPTIONS=--max-old-space-size=160 \
        "$LOADER" --library-path "$LIBRARY_PATH" "$NODE" "$MATTERBRIDGE" "$@"
}

ensure_toon_plugin() {
    test -r "$PLUGIN_PACKAGE" || exit 1
    test -s "$PLUGIN_REGISTRY" && return 0

    mkdir -p "$(dirname "$PLUGIN_REGISTRY")"
    registry_temp="$PLUGIN_REGISTRY.tmp-$$"
    printf '%s\n' '{"key":"plugins","value":[{"name":"matterbridge-toon","path":"/mnt/data/tsc/matter-service/app-v0.1.0/plugins/matterbridge-toon/package.json","type":"DynamicPlatform","version":"0.2.1","description":"Deel geselecteerde Toon-apparaten lokaal via Matter","author":"djvanleest","enabled":true,"private":false}]}' >"$registry_temp"
    mv "$registry_temp" "$PLUGIN_REGISTRY"
}

start_service() {
    test -x "$LOADER" || exit 1
    test -x "$NODE" || exit 1
    test -r "$MATTERBRIDGE" || exit 1
    is_running && exit 0

    mkdir -p "$MATTERBRIDGE_HOME" "$STATUS_ROOT" "$LOG_ROOT"
    # Node crasht met "ENOENT uv_cwd" als de werkmap van de aanroeper niet
    # meer bestaat (zoals bij installatie via het TSC-hulpscript).
    cd "$MATTERBRIDGE_HOME" 2>/dev/null || cd /
    # Bij een lokale npm-installatie zoekt Matterbridge zijn frontend in de
    # app-map in plaats van in node_modules/matterbridge.
    test -e "$APP_ROOT/apps" || ln -s node_modules/matterbridge/apps "$APP_ROOT/apps"
    activate_matter_swap
    ensure_toon_plugin
    allow_matter_traffic
    run_matterbridge \
        --bridge \
        --homedir "$MATTERBRIDGE_HOME" \
        --mdnsinterface wlan0 \
        --passcode 62850275 \
        --discriminator 3564 \
        --logger info \
        --matterlogger warn \
        --novirtual \
        --no-ansi \
        --fixed_delay 0 >>"$LOG_FILE" 2>&1 &
    service_pid=$!
    echo "$service_pid" >"$PID_FILE"
    # Toon has limited RAM. Keep its user interface responsive and make the
    # bridge, rather than qt-gui, the preferred victim if memory is exhausted.
    /usr/bin/renice 10 "$service_pid" >/dev/null 2>&1 || true
    echo 500 >"/proc/$service_pid/oom_score_adj" 2>/dev/null || true
    sleep 2
    is_running || {
        rm -f "$PID_FILE"
        exit 1
    }
}

stop_service() {
    if is_running; then
        service_pid=$(sed -n '1p' "$PID_FILE")
        kill "$service_pid" 2>/dev/null
        attempt=0
        while is_running && test "$attempt" -lt 30; do
            usleep 100000 2>/dev/null || sleep 1
            attempt=$((attempt + 1))
        done
        is_running && kill -9 "$service_pid" 2>/dev/null
    fi
    rm -f "$PID_FILE"
}

case "$1" in
    start) start_service ;;
    stop) stop_service ;;
    restart) stop_service; start_service ;;
    status) is_running && echo running || { echo stopped; exit 1; } ;;
    cli) shift; run_matterbridge --homedir "$MATTERBRIDGE_HOME" --no-ansi --nosudo "$@" ;;
    *) echo "Gebruik: $0 {start|stop|restart|status|cli}"; exit 2 ;;
esac
