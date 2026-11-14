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
    opt/smartcity/dashboard \
    etc/rsyslog.d/30-smartcity.conf \
    etc/cron.d/smartcity \
    etc/systemd/system/smartcity-dashboard.service; do
    [[ -e "/$item" ]] && items+=("$item")
done
((${#items[@]} > 0)) || die "No project files were found to back up."

stamp=$(date '+%Y%m%dT%H%M%S')
archive="$BACKUP_DIR/smartcity-backup-$stamp.tar.gz"
[[ ! -e $archive ]] || archive="$BACKUP_DIR/smartcity-backup-$stamp-$$.tar.gz"
archive_tmp=$(mktemp "$BACKUP_DIR/.smartcity-backup.XXXXXX")
staging_root=""
cleanup() {
    [[ ! -e ${archive_tmp:-} ]] || rm -f -- "$archive_tmp"
    [[ -z ${staging_root:-} || ! -d $staging_root ]] || rm -rf -- "$staging_root"
}
trap cleanup EXIT
dashboard_db=/var/lib/smartcity-dashboard/smartcity.sqlite3
if [[ -f $dashboard_db ]]; then
    [[ -f $SCRIPT_DIR/backup_dashboard_db.py ]] || die "SQLite backup helper is missing: $SCRIPT_DIR/backup_dashboard_db.py"
    require_cmd python3
    staging_root=$(mktemp -d)
    install -d -m 0700 "$staging_root/var/lib/smartcity-dashboard"
    python3 "$SCRIPT_DIR/backup_dashboard_db.py" --source "$dashboard_db" \
        --destination "$staging_root/var/lib/smartcity-dashboard/smartcity.sqlite3"
fi
tar_args=(--create --gzip --file="$archive_tmp" --directory=/ "${items[@]}")
if [[ -n $staging_root ]]; then
    tar_args+=(--directory="$staging_root" var/lib/smartcity-dashboard/smartcity.sqlite3)
fi
tar "${tar_args[@]}"
gzip -t -- "$archive_tmp" || die "Backup integrity check failed."
mv -- "$archive_tmp" "$archive"
archive_tmp=""
chmod 0600 "$archive"
log "Created and validated $archive"
