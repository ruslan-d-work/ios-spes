#!/bin/bash
# What the phone's display shows now, as a PNG (kernel sysctl debug.spes_fb_shot, patch 0180).
#   spes-shot.sh OUT.png [SCALE]     SCALE: also write OUT.small.png, 1/SCALE the size (default 4)
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd); out=${1:?usage: spes-shot.sh OUT.png [SCALE]}; scale=${2:-4}
raw=$(mktemp); trap 'rm -f "$raw"' EXIT
ssh -i "$root/research/ssh/id_ed25519" -o IdentitiesOnly=yes -o UserKnownHostsFile="$root/research/ssh/known_hosts" \
    -o ConnectTimeout=8 root@192.168.7.2 '/usr/sbin/sysctl -b debug.spes_fb_shot' > "$raw"
python3 - "$raw" "$out" "$scale" <<'PY'
import struct, sys
from PIL import Image
d = open(sys.argv[1], 'rb').read()
w, h = struct.unpack('<II', d[:8])
assert len(d) == 8 + w * h * 4, (len(d), w, h)
im = Image.frombuffer('RGBA', (w, h), d[8:], 'raw', 'BGRA', 0, 1).convert('RGB')
im.save(sys.argv[2])
s = int(sys.argv[3])
small = sys.argv[2].rsplit('.', 1)[0] + '.small.png'
im.resize((w // s, h // s), Image.LANCZOS).save(small)
print(f'{sys.argv[2]}: {w}x{h}; {small}')
PY
