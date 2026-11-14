#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_root
require_cmd systemctl
require_cmd mountpoint
mountpoint -q /srv/smartcity/archives || die "The LVM archive filesystem must be mounted before installing Cron jobs."
readonly SOURCE_FILE=/opt/smartcity/config/cron/smartcity
readonly TARGET_FILE=/etc/cron.d/smartcity
[[ -r "$SOURCE_FILE" ]] || die "Cron config missing: $SOURCE_FILE. Run install_project.sh first."
if [[ -e $TARGET_FILE ]]; then
    backup="${TARGET_FILE}.bak.$(date '+%Y%m%d%H%M%S')"
    cp -a -- "$TARGET_FILE" "$backup"
    log "Preserved previous Cron config at $backup"
fi
install -o root -g root -m 0644 "$SOURCE_FILE" "$TARGET_FILE"
systemctl enable --now cron
systemctl is-active --quiet cron || die "Cron service did not become active."
log "Installed $TARGET_FILE and enabled the cron service."
