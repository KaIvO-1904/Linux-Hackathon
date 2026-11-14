#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/lib/common.sh"
usage() { printf 'Usage: %s --device /dev/DEVICE [--apply]\n' "$(basename -- "$0")"; }
device=""
apply=false
while (($#)); do
    case "$1" in
        --device) (($# >= 2)) || { usage >&2; exit 2; }; device=$2; shift 2 ;;
        --apply) apply=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; die "Unknown argument: $1" ;;
    esac
done
[[ -n $device ]] || { usage >&2; exit 2; }
[[ -b $device ]] || die "Not a block device: $device. Inspect disks on the Ubuntu VM first."
device=$(readlink -f -- "$device")
printf 'Selected block device: %s\n' "$device"
lsblk -o NAME,PATH,SIZE,TYPE,FSTYPE,MOUNTPOINTS -- "$device"
if [[ $apply != true ]]; then
    printf 'Inspection only. Nothing was changed.\nAfter confirming this is a dedicated empty data disk, rerun with --apply.\n'
    exit 0
fi
require_root
for command_name in pvcreate vgcreate lvcreate vgs lvs mkfs.ext4 wipefs blkid lsblk findmnt swapon; do require_cmd "$command_name"; done
readonly VG_NAME=smartcity_vg LV_NAME=archives MOUNT_POINT=/srv/smartcity/archives
readonly LV_PATH=/dev/$VG_NAME/$LV_NAME
if vgs "$VG_NAME" >/dev/null 2>&1 || lvs "$LV_PATH" >/dev/null 2>&1; then
    die "LVM name $VG_NAME or $LV_PATH already exists; inspect it instead of overwriting it."
fi
if [[ -e $MOUNT_POINT ]] && [[ -n $(find "$MOUNT_POINT" -mindepth 1 -maxdepth 1 -print -quit) ]]; then
    die "$MOUNT_POINT is not empty. Move or back up its contents before using it as a mount point."
fi
if grep -Eq '^[[:space:]]*[^#].*[[:space:]]/srv/smartcity/archives[[:space:]]' /etc/fstab; then
    die "/etc/fstab already contains an entry for $MOUNT_POINT. Inspect it before proceeding."
fi
root_source=$(findmnt --noheadings --output SOURCE / | sed 's/\[.*$//')
if [[ -n $root_source ]] && lsblk --inverse --noheadings --output PATH "$root_source" 2>/dev/null | grep -Fxq -- "$device"; then
    die "$device appears to contain the root filesystem. Refusing to initialize it."
fi
if lsblk --noheadings --raw --output MOUNTPOINTS "$device" | grep -q '[^[:space:]]'; then
    die "$device or one of its dependent devices has a mounted filesystem. Refusing to initialize it."
fi
for descendant in $(lsblk --noheadings --raw --output PATH "$device"); do
    if findmnt --noheadings --source "$descendant" >/dev/null 2>&1; then die "$descendant is mounted. Refusing to initialize $device."; fi
    if swapon --noheadings --raw --show=NAME 2>/dev/null | grep -Fxq -- "$descendant"; then die "$descendant is used as swap. Refusing to initialize $device."; fi
done
if wipefs --no-act "$device" 2>/dev/null | grep -Eq '0x[[:xdigit:]]+'; then
    die "$device has existing filesystem/partition signatures. Refusing to overwrite it."
fi
printf '\nHIGH RISK: these operations initialize %s and create a new ext4 filesystem.\nAll existing data/signatures on that device would be destroyed.\n' "$device"
read -r -p "To continue, type the exact device path ($device): " confirmation
[[ $confirmation == "$device" ]] || die "Confirmation did not match; nothing was changed."
pvcreate -- "$device"
vgcreate "$VG_NAME" "$device"
lvcreate --name "$LV_NAME" --extents 80%FREE "$VG_NAME"
mkfs.ext4 -L smartcity_archives "$LV_PATH"
install -d -m 0755 "$MOUNT_POINT"
uuid=$(blkid --output value --match-tag UUID "$LV_PATH")
[[ -n $uuid ]] || die "Could not read filesystem UUID from $LV_PATH."
fstab_backup=$(mktemp /etc/fstab.smartcity.XXXXXX)
cp -a /etc/fstab "$fstab_backup"
printf 'UUID=%s %s ext4 defaults,nofail 0 2\n' "$uuid" "$MOUNT_POINT" >> /etc/fstab
if ! mount "$MOUNT_POINT"; then
    cp -a "$fstab_backup" /etc/fstab; rm -f -- "$fstab_backup"
    die "Mount failed; restored the previous /etc/fstab. Inspect the new LVM filesystem manually."
fi
if ! findmnt --verify --tab-file /etc/fstab; then
    umount "$MOUNT_POINT" || true
    cp -a "$fstab_backup" /etc/fstab; rm -f -- "$fstab_backup"
    die "fstab validation failed; restored the previous /etc/fstab. Inspect the new LVM filesystem manually."
fi
rm -f -- "$fstab_backup"
chown root:root "$MOUNT_POINT"
chmod 0755 "$MOUNT_POINT"
log "Mounted $LV_PATH at $MOUNT_POINT and configured its UUID in /etc/fstab."
lsblk -f -- "$device"
df -hP "$MOUNT_POINT"
