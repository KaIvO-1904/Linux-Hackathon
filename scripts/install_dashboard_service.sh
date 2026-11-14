#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_root
require_cmd systemctl
require_cmd python3
readonly UNIT_SOURCE=/opt/smartcity/config/systemd/smartcity-dashboard.service
readonly UNIT_TARGET=/etc/systemd/system/smartcity-dashboard.service
[[ -r $UNIT_SOURCE && -r /opt/smartcity/dashboard/app.py ]] || die "Dashboard files are missing; run install_project.sh first."
getent passwd smartcity-dashboard >/dev/null || die "Dashboard account is missing; run setup_dashboard_access.sh first."

install -o root -g root -m 0644 "$UNIT_SOURCE" "$UNIT_TARGET"
systemctl daemon-reload
systemctl enable --now smartcity-dashboard.service
systemctl --no-pager --full status smartcity-dashboard.service
log "Dashboard is bound to loopback port 8765. Do not expose this port on the network; use an SSH tunnel from Kali."
