#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

readonly BASE_DIR=/srv/smartcity/logs
readonly DEPARTMENTS=(traffic safety water utilities)

require_root
require_cmd getent
require_cmd groupadd
require_cmd install

install -d -o root -g root -m 0755 "$BASE_DIR"
for department in "${DEPARTMENTS[@]}"; do
    if ! getent group "$department" >/dev/null; then
        groupadd "$department"
        log "Created group: $department"
    else
        log "Group already exists: $department"
    fi
    install -d -o root -g "$department" -m 2770 "$BASE_DIR/$department"
done

log "Department directories are ready under $BASE_DIR."
log "Add only approved existing users with: add_department_user.sh USER GROUP"
