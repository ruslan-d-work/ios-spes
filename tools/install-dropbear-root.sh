#!/bin/bash
# Install dropbear (key login only) into a local iOS root image. Never touches the phone.
#   sudo tools/install-dropbear-root.sh IMAGE STAGE PUBKEY
# STAGE is the unpacked Procursus packages. Files iOS already has are kept.
set -xeuo pipefail

[[ $EUID == 0 && $# == 3 ]]
img=$1 stage=$2 pubkey=$3
here=$(cd "$(dirname "$0")" && pwd)
[[ -f $img && -x $stage/usr/sbin/dropbear && -f $pubkey ]]
grep -q '^ssh-ed25519 ' "$pubkey"

mnt=$(mktemp -d)
cleanup() {
	mountpoint -q "$mnt" && umount "$mnt"
	rmdir "$mnt"
}
trap cleanup EXIT

fsck.hfsplus -fy "$img" | tail -3
mount -t hfsplus -o loop,force "$img" "$mnt"
[[ -f $mnt/System/Library/xpc/launchd.plist ]]

rsync -rlptK --ignore-existing --chown=0:0 \
	--exclude='/Library/' --exclude='/usr/share/' --exclude='/usr/include/' --exclude='/usr/libexec/dropbear-wrapper' \
	"$stage/" "$mnt/"

# Dropbear runs the account's shell (/bin/sh on iOS, which stock iOS does not ship) and checks /etc/shells.
ls -ld "$mnt/bin" "$mnt/bin/sh" || true
grep -E '^root:' "$mnt/private/etc/master.passwd" | cut -d: -f1,8-10 || true
[[ -e $mnt/bin/sh || -L $mnt/bin/sh ]] || ln -s /usr/bin/dash "$mnt/bin/sh"
if [[ ! -f $mnt/private/etc/shells ]]; then
	printf '/bin/sh\n' > "$mnt/private/etc/shells"
	chmod 644 "$mnt/private/etc/shells"
elif ! grep -qx /bin/sh "$mnt/private/etc/shells"; then
	printf '/bin/sh\n' >> "$mnt/private/etc/shells"
fi
cat "$mnt/private/etc/shells"

install -d -o 0 -g 0 -m 0700 "$mnt/private/etc/dropbear"
install -d -o 0 -g 0 -m 0755 "$mnt/private/var/root"
install -d -o 0 -g 0 -m 0700 "$mnt/private/var/root/.ssh"
install -o 0 -g 0 -m 0600 "$pubkey" "$mnt/private/var/root/.ssh/authorized_keys"

python3 "$here/root-add-dropbear.py" "$mnt"
ls -l "$mnt/usr/sbin/dropbear" "$mnt/usr/bin/dash" "$mnt/bin/sh"

sync
umount "$mnt"
fsck.hfsplus -f -n "$img" | tail -3
echo DROPBEAR-OK
