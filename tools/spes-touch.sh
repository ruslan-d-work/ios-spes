#!/bin/bash
# A finger on the phone's touchscreen over SSH (kernel sysctl debug.spes_swipe, patch 0181).
# Panel pixels, 1080x2400, origin top left.
#   spes-touch.sh tap X Y
#   spes-touch.sh swipe X1 Y1 X2 Y2 [TRAVEL_MS [HOLD_MS]]     (default 250 ms, no hold)
#   spes-touch.sh home | switcher | left | right | up | down   (common gestures)
#   spes-touch.sh key N DOWN                                   (sweet_hid_key: 0 is power)
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
run() { ssh -i "$root/research/ssh/id_ed25519" -o IdentitiesOnly=yes -o UserKnownHostsFile="$root/research/ssh/known_hosts" \
    -o ConnectTimeout=8 root@192.168.7.2 "$1"; }
swipe() { # x1 y1 x2 y2 travel_ms hold_ms
  local v=$(( $1 | $2 << 12 | $3 << 24 | $4 << 36 | ($5 / 10) << 48 | ($6 / 100) << 56 ))
  run "/usr/sbin/sysctl -w debug.spes_swipe=$v >/dev/null"
}
case "${1:-}" in
tap) swipe "$2" "$3" "$2" "$3" 50 0 ;;
swipe) swipe "$2" "$3" "$4" "$5" "${6:-250}" "${7:-0}" ;;
# the bottom-edge swipe does nothing when it comes from here (finger 7; cause not known): the Home key does it
home) run "/usr/sbin/sysctl -w debug.spes_key=7 >/dev/null; /usr/sbin/sysctl -w debug.spes_key=6 >/dev/null" ;;
switcher) run "for i in 1 2; do /usr/sbin/sysctl -w debug.spes_key=7 >/dev/null; /usr/sbin/sysctl -w debug.spes_key=6 >/dev/null; done" ;;
left) swipe 900 1300 150 1300 200 0 ;;      # finger moves left: next page
right) swipe 150 1300 900 1300 200 0 ;;
up) swipe 540 1700 540 700 250 0 ;;
down) swipe 540 700 540 1700 250 0 ;;
key) run "/usr/sbin/sysctl -w debug.spes_key=$(( $2 * 2 + $3 )) >/dev/null" ;;
*) sed -n '2,8p' "$0"; exit 2 ;;
esac
