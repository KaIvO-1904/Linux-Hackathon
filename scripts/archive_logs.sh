#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

usage() {
    printf 'Usage: %s [--older-than DAYS] [--execute]\n' "$(basename -- "$0")"
    printf 'Default is a dry run. --execute creates an archive and keeps the source logs.\n'
}

days=7
execute=false
while (($#)); do
    case "$1" in
        --older-than)
            (($# >= 2)) || { usage >&2; exit 2; }
            days=$2
            shift 2
            ;;
        --execute) execute=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; die "Unknown argument: $1" ;;
    esac
done
is_uint "$days" || die "DAYS must be a non-negative integer."
readonly SOURCE_DIR=/srv/smartcity/logs
readonly ARCHIVE_DIR=/srv/smartcity/archives
[[ -d "$SOURCE_DIR" ]] || die "Log directory not found: $SOURCE_DIR"
require_root
require_cmd mountpoint
mountpoint -q "$ARCHIVE_DIR" || die "Archive filesystem is not mounted at $ARCHIVE_DIR; run setup_lvm_storage.sh first."

minutes=$((days * 1440))
manifest=$(mktemp)
archive_tmp=""
cleanup() {
    rm -f -- "$manifest"
    [[ -z $archive_tmp ]] || rm -f -- "$archive_tmp"
}
trap cleanup EXIT
(cd -- "$SOURCE_DIR" && find . -type f -mmin "+$minutes" -print0) > "$manifest"

if [[ ! -s $manifest ]]; then
    log "No log files older than $days day(s) were found."
    exit 0
fi
log "Files older than $days day(s):"
while IFS= read -r -d '' file; do printf '  %s\n' "$file"; done < "$manifest"
if [[ $execute != true ]]; then
    log "Dry run only; pass --execute to create the archive. Original logs will remain."
    exit 0
fi

stamp=$(date '+%Y%m%dT%H%M%S')
archive="$ARCHIVE_DIR/smartcity-logs-$stamp.tar.gz"
[[ ! -e $archive ]] || archive="$ARCHIVE_DIR/smartcity-logs-$stamp-$$.tar.gz"
[[ ! -e $archive ]] || die "Archive destination already exists: $archive"
archive_tmp=$(mktemp "$ARCHIVE_DIR/.smartcity-archive.XXXXXX")
if ! (cd -- "$SOURCE_DIR" && tar --create --gzip --file="$archive_tmp" --null --files-from="$manifest"); then
    die "tar could not create the archive. Source files were not removed."
fi
gzip -t -- "$archive_tmp" || die "Archive integrity check failed. Source files were not removed."
mv --no-clobber -- "$archive_tmp" "$archive"
[[ ! -e $archive_tmp ]] || die "Archive destination appeared during publication: $archive"
archive_tmp=""
log "Created and validated $archive; original logs were retained."
