#!/bin/bash
# Build a boot image from a kernel plus extra boot-args, reset the phone into fastboot from iOS,
# boot the image and wait until the interface is up on Metal and unlocked.
#   spes-cycle.sh KERNEL_DIR NAME ["extra boot-args"]
# KERNEL_DIR holds kernel.development.sweet (xnu/out-NNNN); the image is shim/out/spes-NAME.img.
# The command line is that of shim/out/spes-k0181.img (wwan=1 spespmic=1 ...) plus the extra ones.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd); cd "$root"
kernel=${1:?usage: spes-cycle.sh KERNEL_DIR NAME [extra boot-args]}; name=${2:?name}; extra=${3:-}
ssh_() { ssh -i research/ssh/id_ed25519 -o IdentitiesOnly=yes -o UserKnownHostsFile=research/ssh/known_hosts -o ConnectTimeout=5 root@192.168.7.2 "$@"; }
cmd="$(strings -a shim/out/spes-k0181.img | awk '/^debug=0xc/ && !n++')${extra:+ $extra}"   # (grep -m1 + pipefail: SIGPIPE)
python3 tools/mkpayload.py "$kernel/kernel.development.sweet" shim/out/spes-fullram.adt "shim/out/spes-$name.payload" --cmdline "$cmd" >/dev/null
(cd shim && BOOT_HEADER_VERSION=3 MKBOOTIMG=../tools/mkbootimg-v3.py ./build.sh "out/spes-$name.payload" >/dev/null && cp out/shim-boot.img "out/spes-$name.img")
rm -f "shim/out/spes-$name.payload"
if ! fastboot devices 2>/dev/null | grep -q fastboot; then
  ssh_ '/usr/local/libexec/spes-reboot.sh bootloader' >/dev/null 2>&1 & sleep 15; kill $! 2>/dev/null || true   # (timeout cannot run a function)
  timeout 90 bash -c 'until fastboot devices 2>/dev/null | grep -q fastboot; do sleep 2; done'
fi
log=research/live-k0177va-b2.txt; n=$(wc -l < "$log")
fastboot boot "shim/out/spes-$name.img" 2>&1 | tail -1
timeout 240 bash -c "until ssh -i research/ssh/id_ed25519 -o IdentitiesOnly=yes -o UserKnownHostsFile=research/ssh/known_hosts -o ConnectTimeout=5 root@192.168.7.2 true 2>/dev/null; do sleep 4; done"
timeout 120 bash -c "until tail -n +$n $log | grep -q 'backboardd\]: device Turnip'; do sleep 4; done" || echo "no Metal device line"
sleep 30
tools/spes-touch.sh home; sleep 2; tools/spes-touch.sh home; sleep 2
echo "booted spes-$name.img ($(sha256sum "shim/out/spes-$name.img" | cut -c1-16)), log from line $((n + 1)), extra args: ${extra:-none}"
