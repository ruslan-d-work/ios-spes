#!/bin/sh
# Reset the phone from iOS (kernel sysctl debug.spes_reset, patch 0179, boot-arg spespmic=1).
# "reboot" hangs at "hfs: unmount initiated"; this syncs and resets without unmounting.
#   spes-reboot.sh [bootloader|recovery|system] [warm|hard|keep]
# bootloader = fastboot (default). The second word is the PS_HOLD reset type: hard is what
# Linux uses on this phone (default), keep leaves what the bootloader set.
case "${1:-bootloader}" in
bootloader|fastboot) v=2 ;;
recovery) v=3 ;;
system) v=1 ;;
*) echo "usage: spes-reboot.sh [bootloader|recovery|system] [warm|hard|keep]"; exit 2 ;;
esac
case "${2:-hard}" in
hard) v=$((v + 32)) ;;
warm) v=$((v + 16)) ;;
keep) ;;
*) echo "usage: spes-reboot.sh [bootloader|recovery|system] [warm|hard|keep]"; exit 2 ;;
esac
/usr/local/libexec/spes-rtc.sh save
/usr/bin/sync; /usr/bin/sync
sleep 1
exec /usr/sbin/sysctl -w debug.spes_reset=$v
