#!/bin/bash
# Stop the bluetoothd launch loop on the running phone (over SSH), until real Bluetooth exists.
#
#   tools/spes-disable-bluetoothd.sh           remove com.apple.bluetoothd from the phone's launchd.plist
#   tools/spes-disable-bluetoothd.sh restore   put the saved launchd.plist back
#
# Why: bluetoothd finds no "bluetooth"/"marconi-bt" IORegistry entry and no /dev/cu.bluetooth,
# prints "No bluetooth on this device." and exits 0 in main(); every client lookup of one of its
# 13 Mach services makes launchd exec it again. With the job gone, lookups fail at once and
# CoreBluetooth clients see an unsupported/powered-off adapter.
#
# The phone's /System/Library/xpc/launchd.plist is copied here, patched with
# tools/launchd-remove-jobs.py and written back. The first run keeps the original as
# launchd.plist.pre-nobt on the phone. Takes effect at the next boot (launchd_unsecure_cache=1
# is in every spes cmdline); nothing is stopped now. Only the root file system is touched.
# Verify after a reboot: tools/spes-run.sh log | grep -c 'exec bluetoothd' stays at 0.
set -euo pipefail

cd "$(dirname "$0")/.."
phone=192.168.7.2
key=research/ssh/id_ed25519
ssh_args=(-i "$key" -o IdentitiesOnly=yes -o UserKnownHostsFile=research/ssh/known_hosts
	-o StrictHostKeyChecking=accept-new -o ConnectTimeout=6 -o BatchMode=yes)
plist=/System/Library/xpc/launchd.plist
backup=$plist.pre-nobt
on_phone() { ssh "${ssh_args[@]}" root@"$phone" "$@"; }

if [[ ${1:-} == restore ]]; then
	on_phone "test -f $backup && cp -p $backup $plist && sync && echo restored $plist from $backup"
	exit
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
on_phone "test -f $backup || cp -p $plist $backup"
on_phone "cat $plist" >"$work/launchd.plist"
python3 tools/launchd-remove-jobs.py "$work/launchd.plist" "$work/new.plist" com.apple.bluetoothd
python3 -c 'import plistlib,sys; plistlib.load(open(sys.argv[1],"rb"))' "$work/new.plist"
on_phone "cat > $plist.new && chmod 644 $plist.new && chown root:wheel $plist.new && mv $plist.new $plist && sync" <"$work/new.plist"
echo "done; reboot the phone to apply (restore: $0 restore)"
