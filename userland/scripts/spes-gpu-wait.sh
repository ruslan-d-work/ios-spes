#!/bin/sh
# Run once at boot (launchd job com.spes.gpu-wait). backboardd opens Metal before the kernel's
# RedwoodGPU service registers and then stays on the software path for the whole boot.
# Wait for the service, let it settle, then restart backboardd once so it gets Metal.
# the clock starts at 1969: set it from the PMIC counter first (needs spespmic=1)
/usr/local/libexec/spes-rtc.sh load
i=0
while [ $i -lt 240 ]; do
	/usr/sbin/ioreg -rc RedwoodGPU -d 1 2>/dev/null | grep -q "class RedwoodGPU," && break
	sleep 1
	i=$((i + 1))
done
sleep 4
/usr/bin/killall backboardd
echo "spes-gpu-wait: RedwoodGPU after ${i} s, backboardd restarted"
