#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

usage() {
    printf 'Usage: %s USER {traffic|safety|water|utilities}\n' "$(basename -- "$0")"
}

require_root
[[ $# -eq 2 ]] || { usage >&2; exit 2; }
user=$1
group=$2
case "$group" in
    traffic|safety|water|utilities) ;;
    *) usage >&2; die "Unknown department group: $group" ;;
esac
getent passwd "$user" >/dev/null || die "User does not exist: $user"
getent group "$group" >/dev/null || die "Group does not exist; run setup_departments.sh first."
usermod -aG "$group" "$user"
log "Added $user to supplementary group $group. The user must start a new login session."
