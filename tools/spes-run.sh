#!/bin/bash
# Start and reach iOS on the spesn phone. Writes nothing to the phone's partitions.
# See docs/SPES-RUN.md.
#
#   tools/spes-run.sh            wait for fastboot, boot the image, wait for SSH, set the clock
#   tools/spes-run.sh boot IMG   the same with another image
#   tools/spes-run.sh ssh [CMD]  shell on the phone, or run CMD
#   tools/spes-run.sh time       set the phone's clock from this computer
#   tools/spes-run.sh log [FILE] print the live kernel log (Ctrl+C to stop), and save it to FILE
set -euo pipefail

cd "$(dirname "$0")/.."
image_default=shim/out/spes-wifi1.img
phone=192.168.7.2
key=research/ssh/id_ed25519
ssh_args=(-i "$key" -o IdentitiesOnly=yes -o UserKnownHostsFile=research/ssh/known_hosts
	-o StrictHostKeyChecking=accept-new -o ConnectTimeout=6)

set_time() {
	# After every boot the phone's clock starts near 1970, and HTTPS (apt, Sileo) fails.
	ssh "${ssh_args[@]}" -o BatchMode=yes root@"$phone" "date -u -s '$(date -u '+%Y-%m-%d %H:%M:%S')' >/dev/null; date"
}

boot() {
	local image=${1:-$image_default} product='' i
	[[ -f $image ]] || { echo "No image: $image" >&2; exit 1; }
	echo "Waiting for the phone in fastboot (hold power + volume down)..."
	for ((i = 0; i < 120; i++)); do
		product=$(timeout 5 fastboot getvar product 2>&1 | head -1 || true)
		[[ $product == 'product: spesn' ]] && break
		sleep 2
	done
	[[ $product == 'product: spesn' ]] || { echo "Phone not found in fastboot" >&2; exit 1; }
	fastboot boot "$image"
	echo "Booted $image. Waiting for SSH (USB network comes up in about a minute)..."
	for ((i = 0; i < 60; i++)); do
		if ssh "${ssh_args[@]}" -o BatchMode=yes root@"$phone" true 2>/dev/null; then
			echo "SSH is up."
			set_time
			echo "Log in: tools/spes-run.sh ssh"
			return 0
		fi
		sleep 5
	done
	echo "No SSH after 5 minutes. A first boot after a reflash takes about 15 minutes." >&2
	exit 1
}

case ${1:-boot} in
boot) boot "${2:-}" ;;
ssh)
	shift
	exec ssh "${ssh_args[@]}" root@"$phone" "$@"
	;;
time) set_time ;;
log)
	if [[ -n ${2:-} ]]; then
		nc -ukl 5140 | tee -a "$2"
	else
		nc -ukl 5140
	fi
	;;
*)
	sed -n 2,9p "$0"
	exit 2
	;;
esac
