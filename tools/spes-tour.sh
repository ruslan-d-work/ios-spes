#!/bin/bash
# Open the screens whose backdrops are wrong and take a picture of each (needs kernel 0181).
#   spes-tour.sh DIR     -> DIR/{home,applib,switcher,tabs}.png and DIR/sheet.png (1/5 size, side by side)
# Starts from any state: Home twice unlocks and goes to the first page.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd); d=${1:?usage: spes-tour.sh DIR}; mkdir -p "$d"
T="$root/tools/spes-touch.sh"; shot() { "$root/tools/spes-shot.sh" "$d/$1.png" 5 >/dev/null; }
run() { ssh -i "$root/research/ssh/id_ed25519" -o IdentitiesOnly=yes -o UserKnownHostsFile="$root/research/ssh/known_hosts" \
    -o ConnectTimeout=8 root@192.168.7.2 "$1"; }
"$T" home; sleep 2; "$T" home; sleep 2; shot home
"$T" left; sleep 2; "$T" left; sleep 3; shot applib
"$T" home; sleep 2
run 'uiopen -b com.apple.mobilesafari' || true; sleep 6
"$T" tap 1010 2255; sleep 3; shot tabs         # the tabs button, bottom right
"$T" home; sleep 2
"$T" switcher; sleep 3; shot switcher
"$T" home; sleep 1
python3 - "$d" <<'PY'
import sys
from PIL import Image
d = sys.argv[1]; names = ['home', 'applib', 'tabs', 'switcher']
ims = [Image.open(f'{d}/{n}.small.png') for n in names]
w, h = ims[0].size; s = Image.new('RGB', (w * len(ims), h))
for i, im in enumerate(ims): s.paste(im, (i * w, 0))
s.save(d + '/sheet.png')
PY
