#!/bin/sh
# The PM6125 RTC is a counter that cannot be set (kernel sysctl hw.spes_rtc, patch 0179,
# boot-arg spespmic=1). Keep "wall clock - counter" in a file and add it back at boot.
#   spes-rtc.sh save   the clock is right now: remember the difference
#   spes-rtc.sh load   set the clock from the counter (boot, from spes-gpu-wait.sh)
F=/var/db/spes-rtc-offset
rtc=$(/usr/sbin/sysctl -n hw.spes_rtc 2>/dev/null) || rtc=
case "$rtc" in ''|*[!0-9]*) echo "spes-rtc: no hw.spes_rtc"; exit 1 ;; esac
case "$1" in
save)
	now=$(/usr/bin/date +%s)
	[ "$now" -gt 1700000000 ] || { echo "spes-rtc: the clock is not set, nothing saved"; exit 1; }
	echo $((now - rtc)) > $F.new && /bin/mv $F.new $F
	echo "spes-rtc: saved offset $((now - rtc)) (counter $rtc)"
	;;
load)
	off=$(/bin/cat $F 2>/dev/null) || off=
	case "$off" in ''|*[!0-9]*) echo "spes-rtc: no saved offset"; exit 1 ;; esac
	t=$((rtc + off))
	[ "$t" -gt 1700000000 ] || { echo "spes-rtc: counter $rtc + offset $off is not a date"; exit 1; }
	/usr/bin/date -u -s "@$t" >/dev/null && echo "spes-rtc: clock set from the PMIC counter ($rtc + $off)"
	;;
*)
	echo "usage: spes-rtc.sh save|load"; exit 2 ;;
esac
