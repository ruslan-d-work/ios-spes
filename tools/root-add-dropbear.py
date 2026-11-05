#!/usr/bin/env python3
"""Add an always-on, key-only dropbear job to a mounted iOS root (launchd.plist).

  root-add-dropbear.py MOUNTED_ROOT

The job restarts on exit and listens on all interfaces, which today means the kernel's USB
interface ue0 (192.168.7.2, sweetusb=2); Wi-Fi would also reach it if it comes up. Host keys are
made on first connection (-R) in /etc/dropbear. Passwords are refused (-s).
"""
import os
import plistlib
import sys


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    path = os.path.join(sys.argv[1], 'System/Library/xpc/launchd.plist')
    st = os.stat(path)
    with open(path, 'rb') as f:
        plist = plistlib.load(f)
    label = 'com.spes.dropbear'
    plist['LaunchDaemons'][f'/System/Library/LaunchDaemons/{label}.plist'] = {
        'Label': label,
        'ProgramArguments': ['/usr/sbin/dropbear', '-F', '-E', '-R', '-s', '-p', '22'],
        'RunAtLoad': True,
        'KeepAlive': True,
        'ThrottleInterval': 10,
        'UserName': 'root',
        'POSIXSpawnType': 'Interactive',
        'StandardOutPath': '/dev/console',
        'StandardErrorPath': '/dev/console',
    }
    with open(path, 'wb') as f:
        plistlib.dump(plist, f, fmt=plistlib.FMT_BINARY)
    os.chown(path, st.st_uid, st.st_gid)
    os.chmod(path, st.st_mode & 0o7777)
    print(f'launchd.plist: {label} added')


if __name__ == '__main__':
    main()
