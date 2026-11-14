#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_root
require_cmd tar
require_cmd gzip
require_cmd flock
readonly BACKUP_DIR=/srv/smartcity/backups
install -d -m 0700 "$BACKUP_DIR"

# Serialize manual and Cron runs. flock is released by the kernel if the
# process exits or is killed, so a stale lock file cannot block future runs.
exec {backup_lock_fd}>"$BACKUP_DIR/.backup.lock"
if ! flock -n "$backup_lock_fd"; then
    log "Another backup is already running; skipping this invocation."
    exit 0
fi

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
[[ ! -e $archive ]] || die "Backup destination already exists: $archive"
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
chmod 0600 "$archive_tmp"
mv --no-clobber -- "$archive_tmp" "$archive"
[[ ! -e $archive_tmp ]] || die "Backup destination appeared during publication: $archive"
archive_tmp=""
log "Created and validated $archive"
