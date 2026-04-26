#!/bin/bash

set -eu

MTU=1280
FWMARK=0xca6c
TIMEOUT=120
LAN_SUBNET=192.168.1.0/24
GATEWAY_ADDRESS=192.168.1.1

lan_only=0
wait_for_route=0
wait_for_gateway=0
for arg in "$@"; do
  case "$arg" in
    --lan-only) lan_only=1 ;;
    --wait-for-route) wait_for_route=1 ;;
    --wait-for-gateway) wait_for_gateway=1 ;;
    *) echo "Usage: $0 [--lan-only] [--wait-for-route] [--wait-for-gateway]" >&2; exit 1 ;;
  esac
done

if [ "$wait_for_route" = "1" ]; then
  exec {monitor4_fd}< <(timeout $TIMEOUT ip -4 monitor rule route)
  exec {monitor6_fd}< <(timeout $TIMEOUT ip -6 monitor rule route)
fi

wait_gateway_reachable() {
  ping -4 -c 1 -w "$TIMEOUT" "$GATEWAY_ADDRESS" >/dev/null 2>&1 ||
    echo "Timed out waiting for $GATEWAY_ADDRESS to become reachable" >&2
}

ip_or_monitor() {
  local pattern="$1"; shift
  local awk_expr="match(\$0, $pattern, a) { print a[1]; exit }"
  local out=$(ip "$@" | gawk "$awk_expr")
  if [ "$wait_for_route" = "1" ] && [ -z "$out" ]; then
    local monitor_fd_var="monitor${1:1}_fd"
    out=$(gawk "!/Deleted/ && $awk_expr" <&"${!monitor_fd_var}")
  fi
  printf '%s' "$out"
}

get_fwmark_table() {
  ip_or_monitor "/fwmark $FWMARK lookup (\\S+)/" $1 rule
}

get_default_route() {
  [ -n "$2" ] || return 0
  ip_or_monitor "/(default .* table $2.*)/" $1 route show table all
}

clamp_route_mtu() {
  [ -n "$2" ] || return 0
  ip $1 route replace $2 mtu "$MTU"
}

[ "$wait_for_gateway" != "1" ] || wait_gateway_reachable

table4=$(get_fwmark_table -4)
table6=$(get_fwmark_table -6)
route4=$(get_default_route -4 "$table4")
route6=$(get_default_route -6 "$table6")

if [ "$lan_only" = "1" ]; then
  if [ -n "$route4" ]; then
    ip -4 route del default table "$table4"
    ip -4 route replace "$LAN_SUBNET" $(echo "$route4" | sed 's/^default//') mtu "$MTU"
  fi
  ip -6 route del default table "$table6" 2>/dev/null || true
else
  clamp_route_mtu -4 "$route4"
  clamp_route_mtu -6 "$route6"
fi
