#!/bin/sh

set -eu

MTU=1280
FWMARK=0xca6c
LAN_SUBNET=192.168.1.0/24

lan_only=0
for arg in "$@"; do
  case "$arg" in
    --lan-only) lan_only=1 ;;
    *) echo "Usage: $0 [--lan-only]" >&2; exit 1 ;;
  esac
done

table=$(ip rule | awk "/fwmark $FWMARK/ {print \$NF; exit}")
[ -z "$table" ] && exit 0

get_default_route() {
  ip $1 route show table "$table" | awk '$1=="default" {print; exit}'
}

clamp_default_route_mtu() {
  d=$(get_default_route $1)
  [ -n "$d" ] && ip $1 route replace $d mtu "$MTU" table "$table"
}

if [ "$lan_only" = "1" ]; then
  d=$(get_default_route -4)
  if [ -n "$d" ]; then
    ip -4 route del default table "$table"
    ip -4 route replace "$LAN_SUBNET" $(echo "$d" | sed 's/^default//') mtu "$MTU" table "$table"
  fi
  ip -6 route del default table "$table" 2>/dev/null || true
else
  clamp_default_route_mtu -4
  clamp_default_route_mtu -6
fi
