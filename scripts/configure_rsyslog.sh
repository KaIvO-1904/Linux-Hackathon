#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_root
require_cmd rsyslogd
require_cmd systemctl
readonly SOURCE_CONFIG=/opt/smartcity/config/rsyslog/30-smartcity.conf
readonly TARGET_CONFIG=/etc/rsyslog.d/30-smartcity.conf
[[ -r "$SOURCE_CONFIG" ]] || die "Project config missing: $SOURCE_CONFIG. Run install_project.sh first."
[[ -d /srv/smartcity/logs/traffic && -d /srv/smartcity/logs/safety && -d /srv/smartcity/logs/water && -d /srv/smartcity/logs/utilities ]] || {
    die "Department directories missing; run setup_departments.sh first."
}

backup=""
if [[ -e "$TARGET_CONFIG" ]]; then
    backup="${TARGET_CONFIG}.bak.$(date '+%Y%m%d%H%M%S')"
    cp -a -- "$TARGET_CONFIG" "$backup"
    log "Preserved previous config at $backup"
fi
install -o root -g root -m 0644 "$SOURCE_CONFIG" "$TARGET_CONFIG"
if ! rsyslogd -N1; then
    log "Validation failed; removing the project config and restoring the previous file if available."
    rm -f -- "$TARGET_CONFIG"
    if [[ -n $backup ]]; then cp -a -- "$backup" "$TARGET_CONFIG"; fi
    exit 1
fi
if ! systemctl restart rsyslog || ! systemctl is-active --quiet rsyslog; then
    log "rsyslog failed to restart; restoring the previous project config."
    if [[ -n $backup ]]; then
        cp -a -- "$backup" "$TARGET_CONFIG"
    else
        rm -f -- "$TARGET_CONFIG"
    fi
    systemctl restart rsyslog || true
    die "rsyslog did not become active. Inspect: systemctl status rsyslog"
fi
log "Local department routing is active. Remote syslog listening is not enabled by this config."
