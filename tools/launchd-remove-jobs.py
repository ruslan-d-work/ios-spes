#!/usr/bin/env python3
"""Remove launchd jobs (by Label) from launchd.plist.

  launchd-remove-jobs.py IN.plist OUT.plist LABEL [LABEL ...]

IN is /System/Library/xpc/launchd.plist (binary plist, read by launchd when booted with
launchd_unsecure_cache=1). Every job whose Label is given is deleted together with its
MachServices, so nothing launches it on demand any more. Labels that are not present are
reported and skipped (removing twice is harmless). OUT may equal IN.

Use: com.apple.bluetoothd on spesn. Without a bluetooth IORegistry entry and without
/dev/cu.bluetooth it prints "No bluetooth on this device." and exits 0 (errx(0, ...)) right
in main; launchd starts it again for every client that looks up one of its Mach services,
which is the endless 'exec bluetoothd' in every boot log.
"""
import plistlib
import sys


def main():
    if len(sys.argv) < 4:
        sys.exit(__doc__)
    src, dst, labels = sys.argv[1], sys.argv[2], set(sys.argv[3:])
    with open(src, 'rb') as f:
        plist = plistlib.load(f)
    jobs = plist['LaunchDaemons']
    removed = [k for k, j in jobs.items() if j.get('Label') in labels]
    found = {jobs[k]['Label'] for k in removed}
    for k in removed:
        del jobs[k]
    with open(dst, 'wb') as f:
        plistlib.dump(plist, f, fmt=plistlib.FMT_BINARY)
    for k in removed:
        print(f'removed {k}')
    for label in sorted(labels - found):
        print(f'not present: {label}')


if __name__ == '__main__':
    main()
