#!/usr/bin/env python3
"""Minimal Android boot image v3 packer for shim/build.sh (no AOSP checkout needed).

  MKBOOTIMG=$PWD/tools/mkbootimg-v3.py BOOT_HEADER_VERSION=3 shim/build.sh ...

Takes the subset of AOSP mkbootimg's arguments that shim/build.sh passes.
"""
import argparse
import re
import struct

PAGE = 4096
HEADER_SIZE = 1580


def os_version(version, patch_level):
    m = re.fullmatch(r'(\d+)\.(\d+)\.(\d+)', version)
    p = re.fullmatch(r'(\d{4})-(\d{2})', patch_level)
    if not m or not p:
        raise SystemExit('bad --os_version or --os_patch_level')
    a, b, c = map(int, m.groups())
    year, month = map(int, p.groups())
    return (a << 25) | (b << 18) | (c << 11) | ((year - 2000) << 4) | month


def pad(data):
    return data + b'\0' * (-len(data) % PAGE)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--header_version', type=int, required=True, choices=[3])
    ap.add_argument('--kernel', required=True)
    ap.add_argument('--ramdisk', required=True)
    ap.add_argument('--os_version', required=True)
    ap.add_argument('--os_patch_level', required=True)
    ap.add_argument('--cmdline', default='')
    ap.add_argument('-o', '--output', required=True)
    args = ap.parse_args()

    kernel = open(args.kernel, 'rb').read()
    ramdisk = open(args.ramdisk, 'rb').read()
    cmdline = args.cmdline.encode()
    if len(cmdline) >= 1536:
        raise SystemExit('cmdline too long')

    header = b'ANDROID!' + struct.pack(
        '<IIII4II1536s', len(kernel), len(ramdisk),
        os_version(args.os_version, args.os_patch_level), HEADER_SIZE,
        0, 0, 0, 0, args.header_version, cmdline)
    assert len(header) == HEADER_SIZE
    with open(args.output, 'wb') as f:
        f.write(pad(header) + pad(kernel) + pad(ramdisk))


if __name__ == '__main__':
    main()
