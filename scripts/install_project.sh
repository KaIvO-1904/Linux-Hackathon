#!/usr/bin/env bash
set -Eeuo pipefail

SOURCE_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
INSTALL_ROOT=/opt/smartcity
DATA_ROOT=/srv/smartcity

[[ ${EUID:-$(id -u)} -eq 0 ]] || { printf 'Run with sudo: sudo %s\n' "$0" >&2; exit 1; }
[[ -d "$SOURCE_ROOT/config" && -d "$SOURCE_ROOT/scripts" && -d "$SOURCE_ROOT/dashboard" ]] || {
    printf 'Run this from the complete project bundle; config/, scripts/, or dashboard/ is missing.\n' >&2
    exit 1
}

install -d -o root -g root -m 0755 "$INSTALL_ROOT/scripts" "$INSTALL_ROOT/config" "$INSTALL_ROOT/dashboard" \
    "$DATA_ROOT/logs" "$DATA_ROOT/archives" "$DATA_ROOT/backups" "$DATA_ROOT/reports"
cp -a "$SOURCE_ROOT/scripts/." "$INSTALL_ROOT/scripts/"
cp -a "$SOURCE_ROOT/config/." "$INSTALL_ROOT/config/"
install -o root -g root -m 0644 "$SOURCE_ROOT/dashboard/app.py" "$SOURCE_ROOT/dashboard/index.html" \
    "$SOURCE_ROOT/dashboard/styles.css" "$SOURCE_ROOT/dashboard/app.js" "$SOURCE_ROOT/dashboard/README.md" \
    "$INSTALL_ROOT/dashboard/"
[[ ! -f "$SOURCE_ROOT/dashboard/run.sh" ]] || install -o root -g root -m 0755 "$SOURCE_ROOT/dashboard/run.sh" "$INSTALL_ROOT/dashboard/run.sh"
find "$INSTALL_ROOT/scripts" -type f -name '*.sh' -exec chmod 0755 {} +
find "$INSTALL_ROOT/scripts/lib" -type f -name '*.sh' -exec chmod 0644 {} +
chown -R root:root "$INSTALL_ROOT"
chmod 0755 "$INSTALL_ROOT" "$INSTALL_ROOT/scripts" "$INSTALL_ROOT/config"
chown -R root:root "$INSTALL_ROOT/dashboard"
find "$INSTALL_ROOT/dashboard" -type f -exec chmod 0644 {} +
chmod 0755 "$INSTALL_ROOT/dashboard"
[[ ! -f "$INSTALL_ROOT/dashboard/run.sh" ]] || chmod 0755 "$INSTALL_ROOT/dashboard/run.sh"
printf 'Installed project scripts, configuration, and dashboard to %s\n' "$INSTALL_ROOT"
printf 'Created project data directories under %s\n' "$DATA_ROOT"
