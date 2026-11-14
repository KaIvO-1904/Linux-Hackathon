#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_root
require_cmd tar
require_cmd gzip
readonly BACKUP_DIR=/srv/smartcity/backups
install -d -m 0700 "$BACKUP_DIR"

items=()
for item in \
    srv/smartcity/logs \
    srv/smartcity/archives \
    srv/smartcity/reports \
    opt/smartcity/scripts \
    opt/smartcity/config \
    etc/rsyslog.d/30-smartcity.conf \
    etc/cron.d/smartcity; do
    [[ -e "/$item" ]] && items+=("$item")
done
((${#items[@]} > 0)) || die "No project files were found to back up."

stamp=$(date '+%Y%m%dT%H%M%S')
archive="$BACKUP_DIR/smartcity-backup-$stamp.tar.gz"
[[ ! -e $archive ]] || archive="$BACKUP_DIR/smartcity-backup-$stamp-$$.tar.gz"
archive_tmp=$(mktemp "$BACKUP_DIR/.smartcity-backup.XXXXXX")
cleanup() { [[ ! -e ${archive_tmp:-} ]] || rm -f -- "$archive_tmp"; }
trap cleanup EXIT
tar --create --gzip --file="$archive_tmp" --directory=/ -- "${items[@]}"
gzip -t -- "$archive_tmp" || die "Backup integrity check failed."
mv -- "$archive_tmp" "$archive"
archive_tmp=""
chmod 0600 "$archive"
log "Created and validated $archive"
