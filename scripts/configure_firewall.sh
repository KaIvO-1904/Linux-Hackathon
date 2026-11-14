#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

usage() {
    printf 'Usage: %s [--apply]\n' "$(basename -- "$0")"
    printf 'Default prints the proposed UFW policy. --apply changes firewall rules.\n'
}

apply=false
while (($#)); do
    case "$1" in
        --apply) apply=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; die "Unknown argument: $1" ;;
    esac
done
printf 'Proposed UFW policy: deny inbound, allow outbound, allow OpenSSH (TCP 22).\n'
printf 'This one-VM local-log demo does not need inbound syslog port 514.\n'
if [[ $apply != true ]]; then
    printf 'Dry run only. Run with --apply from the VM console to apply.\n'
    exit 0
fi

require_root
require_cmd ufw
ufw default deny incoming
ufw default allow outgoing
ufw allow OpenSSH
ufw --force enable
ufw status verbose
