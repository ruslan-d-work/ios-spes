#!/bin/bash
# The same UI workload each time, then the GPU's time a submission from the kernel log
# (RedwoodGPU's 5 s summaries) and the touch -> next frame latency, for that window only.
#   spes-bench.sh LABEL
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd); cd "$root"; T=tools/spes-touch.sh
log=research/live-k0177va-b2.txt; n=$(wc -l < "$log")
$T home; sleep 2
for i in 1 2 3 4; do $T left; sleep 1; $T right; sleep 1; done
$T left; sleep 1; $T left; sleep 2; $T up; sleep 1; $T down; sleep 1; $T home; sleep 2
$T switcher; sleep 3; $T home; sleep 2
$T down; sleep 2; $T home; sleep 3
tail -n +"$n" "$log" | python3 -c '
import re, sys
label = sys.argv[1]
subs = []; gpu = []; lat = []
for l in sys.stdin:
    m = re.search(r"RedwoodGPU: (\d+) submissions in (\d+) ms: .* the GPU worked (\d+) us on each", l)
    if m: subs.append((int(m.group(1)), int(m.group(2)))); gpu.append((int(m.group(1)), int(m.group(3))))
    m = re.search(r"touch -> next swap ([\d.]+) ms", l)
    if m: lat.append(float(m.group(1)))
    m = re.search(r"markers sysmem (\d+) binning (\d+) gmem (\d+)", l)
    if m: mode = m.groups()
n = sum(s for s, _ in gpu)
mean = sum(s * g for s, g in gpu) / n if n else 0
lat.sort()
med = lat[len(lat) // 2] if lat else 0; p90 = lat[int(len(lat) * 0.9)] if lat else 0
rate = sum(s for s, _ in subs) * 1000 / sum(ms for _, ms in subs) if subs else 0
print(f"{label}: {n} submissions, GPU {mean/1000:.1f} ms each (mean), {rate:.1f}/s in busy windows; touch->frame median {med:.0f} ms p90 {p90:.0f} ms (n={len(lat)})")
' "$1"
