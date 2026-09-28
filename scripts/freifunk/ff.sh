#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------
# Freifunk network namespace launcher
#
# Usage:
#   ./ff.sh curl -4 https://ifconfig.me
#   ./ff.sh firefox
#   ./ff.sh bash
#
# Application traffic from the namespace is routed through ff0.
# Host networking is restored when the application exits.
# ------------------------------------------------------------

NS="freifunk"

VETH_HOST="veth-ff"
VETH_NS="veth-ns"

HOST_IP="10.200.0.1/24"
NS_IP="10.200.0.2/24"

FF_IF="ff0"

ROUTE_TABLE="200"
RULE_PRIORITY="100"

# ------------------------------------------------------------
# Re-exec as root
# ------------------------------------------------------------

if [[ "$EUID" -ne 0 ]]; then
    exec sudo "$0" "$@"
fi

# ------------------------------------------------------------
# User that invoked the script
# ------------------------------------------------------------

RUN_USER="${SUDO_USER:-$USER}"
RUN_UID="$(id -u "$RUN_USER")"
RUN_GID="$(id -g "$RUN_USER")"
RUN_HOME="$(getent passwd "$RUN_UID" | cut -d: -f6)"
RUN_XDG_RUNTIME_DIR="/run/user/$RUN_UID"

# ------------------------------------------------------------
# Verify required commands
# ------------------------------------------------------------

for cmd in ip nft sysctl setpriv; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "ERROR: required command not found: $cmd" >&2
        exit 1
    fi
done

# ------------------------------------------------------------
# Freifunk configuration
# ------------------------------------------------------------

if ! ip link show "$FF_IF" >/dev/null 2>&1; then
    echo "ERROR: interface $FF_IF does not exist." >&2
    exit 1
fi

FF_ADDR="$(
    ip -4 -o addr show dev "$FF_IF" |
        awk '{print $4; exit}'
)"

if [[ -z "$FF_ADDR" ]]; then
    echo "ERROR: $FF_IF has no IPv4 address." >&2
    exit 1
fi

FF_IP="${FF_ADDR%/*}"

FF_NETWORK="$(
    ip -4 route show dev "$FF_IF" scope link |
        awk '$1 ~ /^[0-9]+\./ {print $1; exit}'
)"

FF_GW="$(
    ip -4 route show default dev "$FF_IF" |
        awk '$1 == "default" {print $3; exit}'
)"

if [[ -z "$FF_NETWORK" || -z "$FF_GW" ]]; then
    echo "ERROR: could not determine Freifunk network/gateway." >&2
    echo
    ip -4 route show dev "$FF_IF"
    exit 1
fi

echo "Freifunk interface: $FF_IF"
echo "Freifunk address:   $FF_IP"
echo "Freifunk network:   $FF_NETWORK"
echo "Freifunk gateway:   $FF_GW"
echo

# ------------------------------------------------------------
# Save host state
# ------------------------------------------------------------

ORIG_IP_FORWARD="$(
    sysctl -n net.ipv4.ip_forward
)"

ORIG_FF_RP_FILTER="$(
    sysctl -n "net.ipv4.conf.${FF_IF}.rp_filter"
)"

echo "Original IP forwarding: $ORIG_IP_FORWARD"
echo "Original $FF_IF rp_filter: $ORIG_FF_RP_FILTER"
echo

# ------------------------------------------------------------
# NixOS rp_filter chain
# ------------------------------------------------------------

RP_BYPASS_CREATED=0

if nft list chain ip mangle nixos-fw-rpfilter >/dev/null 2>&1; then
    if ! nft list chain ip mangle nixos-fw-rpfilter |
        grep -q 'iifname "ff0" return'
    then
        nft insert rule ip mangle nixos-fw-rpfilter \
            iifname "$FF_IF" return

        RP_BYPASS_CREATED=1
    fi
fi

# ------------------------------------------------------------
# Cleanup
# ------------------------------------------------------------

cleanup() {
    set +e

    echo
    echo "Cleaning up..."

    # Namespace nftables
    nft delete table inet "$NS" 2>/dev/null || true

    # Policy routing
    ip rule del \
        from 10.200.0.0/24 \
        priority "$RULE_PRIORITY" \
        2>/dev/null || true

    ip route flush table "$ROUTE_TABLE" 2>/dev/null || true

    # Namespace/veth
    ip link del "$VETH_HOST" 2>/dev/null || true
    ip netns del "$NS" 2>/dev/null || true

    # Namespace DNS
    rm -rf "/etc/netns/$NS"

    # Restore ff0 rp_filter
    echo "Restoring $FF_IF.rp_filter = $ORIG_FF_RP_FILTER"

    sysctl -q -w \
        "net.ipv4.conf.${FF_IF}.rp_filter=${ORIG_FF_RP_FILTER}" \
        || true

    # Remove only the rule created by this invocation
    if [[ "$RP_BYPASS_CREATED" -eq 1 ]]; then
        HANDLE="$(
            nft -a list chain ip mangle nixos-fw-rpfilter 2>/dev/null |
                awk '
                    /iifname "ff0" return/ {
                        for (i = 1; i <= NF; i++) {
                            if ($i == "handle") {
                                print $(i + 1)
                                exit
                            }
                        }
                    }
                '
        )"

        if [[ -n "$HANDLE" ]]; then
            nft delete rule \
                ip mangle nixos-fw-rpfilter \
                handle "$HANDLE" \
                2>/dev/null || true
        fi
    fi

    # Restore IP forwarding
    echo "Restoring net.ipv4.ip_forward = $ORIG_IP_FORWARD"

    sysctl -q -w \
        "net.ipv4.ip_forward=${ORIG_IP_FORWARD}" \
        || true
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# ------------------------------------------------------------
# Remove stale state from previous invocation
# ------------------------------------------------------------

nft delete table inet "$NS" 2>/dev/null || true

ip rule del \
    from 10.200.0.0/24 \
    priority "$RULE_PRIORITY" \
    2>/dev/null || true

ip route flush table "$ROUTE_TABLE" 2>/dev/null || true

ip link del "$VETH_HOST" 2>/dev/null || true
ip netns del "$NS" 2>/dev/null || true

rm -rf "/etc/netns/$NS"

# ------------------------------------------------------------
# Namespace
# ------------------------------------------------------------

ip netns add "$NS"

# ------------------------------------------------------------
# veth pair
# ------------------------------------------------------------

ip link add \
    "$VETH_HOST" \
    type veth \
    peer name "$VETH_NS"

ip link set "$VETH_NS" netns "$NS"

ip addr add "$HOST_IP" dev "$VETH_HOST"
ip link set "$VETH_HOST" up

ip netns exec "$NS" \
    ip link set lo up

ip netns exec "$NS" \
    ip addr add "$NS_IP" dev "$VETH_NS"

ip netns exec "$NS" \
    ip link set "$VETH_NS" up

ip netns exec "$NS" \
    ip route add default via 10.200.0.1

# ------------------------------------------------------------
# Disable IPv6 in namespace
#
# This makes IPv6 unavailable to applications in the namespace,
# preventing an IPv6 path from bypassing Freifunk IPv4 routing.
# ------------------------------------------------------------

ip netns exec "$NS" \
    sysctl -q -w net.ipv6.conf.all.disable_ipv6=1

ip netns exec "$NS" \
    sysctl -q -w net.ipv6.conf.default.disable_ipv6=1

# ------------------------------------------------------------
# Enable IPv4 forwarding
# ------------------------------------------------------------

sysctl -q -w net.ipv4.ip_forward=1

# ------------------------------------------------------------
# Disable reverse-path filtering on ff0
# ------------------------------------------------------------

sysctl -q -w \
    "net.ipv4.conf.${FF_IF}.rp_filter=0"

# ------------------------------------------------------------
# Policy routing
#
# Namespace source addresses:
#   10.200.0.0/24
#
# use:
#   table 200
#
# whose default route points to:
#   ff0 -> Freifunk gateway
# ------------------------------------------------------------

ip route add \
    "$FF_NETWORK" \
    dev "$FF_IF" \
    scope link \
    table "$ROUTE_TABLE"

ip route add \
    default \
    via "$FF_GW" \
    dev "$FF_IF" \
    table "$ROUTE_TABLE"

ip rule add \
    from 10.200.0.0/24 \
    priority "$RULE_PRIORITY" \
    table "$ROUTE_TABLE"

# ------------------------------------------------------------
# nftables
# ------------------------------------------------------------

nft add table inet "$NS"

nft 'add chain inet freifunk forward {
    type filter hook forward priority 0;
    policy drop;
}'

nft 'add chain inet freifunk postrouting {
    type nat hook postrouting priority 100;
    policy accept;
}'

# Namespace -> Freifunk
nft add rule inet "$NS" forward \
    iifname "$VETH_HOST" \
    oifname "$FF_IF" \
    ct state new,established,related \
    accept

# Freifunk -> Namespace
nft add rule inet "$NS" forward \
    iifname "$FF_IF" \
    oifname "$VETH_HOST" \
    ct state established,related \
    accept

# NAT namespace traffic onto Freifunk
nft add rule inet "$NS" postrouting \
    oifname "$FF_IF" \
    ip saddr 10.200.0.0/24 \
    masquerade

# ------------------------------------------------------------
# DNS
# ------------------------------------------------------------

mkdir -p "/etc/netns/$NS"

cat > "/etc/netns/$NS/resolv.conf" <<EOF
nameserver 1.1.1.1
nameserver 9.9.9.9
EOF

# ------------------------------------------------------------
# Diagnostics
# ------------------------------------------------------------

echo "Running through $FF_IF:"
echo

echo "Policy routing:"
ip rule show
echo

echo "Route table $ROUTE_TABLE:"
ip route show table "$ROUTE_TABLE"
echo

echo "Namespace:"
ip netns exec "$NS" ip -br addr
echo

echo "Namespace routes:"
ip netns exec "$NS" ip route
echo

echo "Executing as user: $RUN_USER (uid $RUN_UID)"
echo "Executing: $*"
echo

# ------------------------------------------------------------
# Execute application as normal user.
#
# Do not exec: cleanup must run afterwards.
# ------------------------------------------------------------

set +e

ip netns exec "$NS" \
    setpriv \
        --reuid="$RUN_UID" \
        --regid="$RUN_GID" \
        --init-groups \
        -- \
        env \
            HOME="$RUN_HOME" \
            USER="$RUN_USER" \
            LOGNAME="$RUN_USER" \
            XDG_RUNTIME_DIR="$RUN_XDG_RUNTIME_DIR" \
            "$@"

APP_STATUS=$?

exit "$APP_STATUS"
