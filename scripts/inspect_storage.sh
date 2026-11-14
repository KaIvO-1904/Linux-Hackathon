#!/usr/bin/env bash
set -Eeuo pipefail

printf 'Block devices (identify the dedicated, empty data disk before considering LVM):\n'
lsblk -o NAME,PATH,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL
printf '\nMounted filesystems:\n'
findmnt --real
if command -v pvs >/dev/null 2>&1; then
    printf '\nExisting LVM physical volumes:\n'
    pvs || true
    printf '\nExisting LVM volume groups:\n'
    vgs || true
    printf '\nExisting LVM logical volumes:\n'
    lvs || true
fi
printf '\nSpace available on root filesystem:\n'
df -hP /
