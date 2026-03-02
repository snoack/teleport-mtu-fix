#!/bin/bash

set -eu

MTU=1280
FWMARK=0xca6c
TIMEOUT=120
LAN_SUBNET=192.168.1.0/24

lan_only=0
wait=0
for arg in "$@"; do
  case "$arg" in
    --lan-only) lan_only=1 ;;
    --wait) wait=1 ;;
    *) echo "Usage: $0 [--lan-only] [--wait]" >&2; exit 1 ;;
  esac
done

deadline=$((SECONDS + TIMEOUT))
attempt=1
while true; do
  table=$(ip rule | awk "/fwmark $FWMARK/ {print \$NF; exit}")
  [ -n "$table" ] && break
  [ "$wait" = "0" ] || [ "$SECONDS" -ge "$deadline" ] && exit 0
  sleep "$(echo "d=0.1*e(1.2*l($attempt)); if(d>1) 1 else d" | bc -l)"
  attempt=$((attempt + 1))
done

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
