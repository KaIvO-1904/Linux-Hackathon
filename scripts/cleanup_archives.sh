#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

usage() {
    printf 'Usage: %s [--keep-days DAYS] [--execute]\n' "$(basename -- "$0")"
    printf 'Default is a dry run; --execute deletes matching archived bundles.\n'
}

keep_days=30
execute=false
while (($#)); do
    case "$1" in
        --keep-days)
            (($# >= 2)) || { usage >&2; exit 2; }
            keep_days=$2
            shift 2
            ;;
        --execute) execute=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; die "Unknown argument: $1" ;;
    esac
done
is_uint "$keep_days" || die "DAYS must be a non-negative integer."
readonly ARCHIVE_DIR=/srv/smartcity/archives
[[ -d "$ARCHIVE_DIR" ]] || die "Archive directory not found: $ARCHIVE_DIR"
require_root
require_cmd mountpoint
mountpoint -q "$ARCHIVE_DIR" || die "Archive filesystem is not mounted at $ARCHIVE_DIR."

manifest=$(mktemp)
trap 'rm -f -- "$manifest"' EXIT
find "$ARCHIVE_DIR" -maxdepth 1 -type f -name 'smartcity-logs-*.tar.gz' -mmin "+$((keep_days * 1440))" -print0 > "$manifest"
if [[ ! -s $manifest ]]; then
    log "No smartcity log archives older than $keep_days day(s) were found."
    exit 0
fi
log "Archives older than $keep_days day(s):"
while IFS= read -r -d '' file; do printf '  %s\n' "$file"; done < "$manifest"
if [[ $execute != true ]]; then
    log "Dry run only; pass --execute to delete these matching archive files."
    exit 0
fi
while IFS= read -r -d '' file; do
    rm -- "$file"
    log "Deleted $file"
done < "$manifest"
