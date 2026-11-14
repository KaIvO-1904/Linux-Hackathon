#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/lib/common.sh"
usage() {
    printf 'Usage: %s [--apply]\n' "$(basename -- "$0")"
    printf 'Default inspects the target. --apply grows the LV/filesystem using all remaining VG space.\n'
}
apply=false
while (($#)); do
    case "$1" in
        --apply) apply=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; die "Unknown argument: $1" ;;
    esac
done
readonly VG_NAME=smartcity_vg
readonly LV_PATH=/dev/smartcity_vg/archives
readonly MOUNT_POINT=/srv/smartcity/archives
require_cmd vgs
require_cmd lvs
require_cmd findmnt
[[ -e $LV_PATH ]] || die "Logical volume not found: $LV_PATH"
findmnt --noheadings --source "$LV_PATH" --target "$MOUNT_POINT" >/dev/null || die "$LV_PATH is not mounted at $MOUNT_POINT"
free_bytes=$(vgs --noheadings --units b --nosuffix --options vg_free "$VG_NAME" | awk '{$1=$1; print $1}')
awk -v free="$free_bytes" 'BEGIN { if (free+0 <= 0) exit 1 }' || die "Volume group has no free extents to add."
lvs --units g --options lv_name,lv_size,vg_name "$VG_NAME"
vgs --units g --options vg_name,vg_size,vg_free "$VG_NAME"
df -hP "$MOUNT_POINT"
[[ $apply == true ]] || { printf 'Inspection only; no changes made.\n'; exit 0; }
require_root
require_cmd lvextend
printf '\nThis will add all remaining free extents in %s to %s and grow the mounted filesystem.\n' "$VG_NAME" "$LV_PATH"
read -r -p "Type $LV_PATH to continue: " confirmation
[[ $confirmation == "$LV_PATH" ]] || die "Confirmation did not match; nothing was changed."
lvextend --resizefs --extents +100%FREE "$LV_PATH"
log "Extended logical volume and filesystem."
lvs --units g --options lv_name,lv_size,vg_name "$VG_NAME"
vgs --units g --options vg_name,vg_size,vg_free "$VG_NAME"
df -hP "$MOUNT_POINT"
