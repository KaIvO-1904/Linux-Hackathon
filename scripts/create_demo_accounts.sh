#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/lib/common.sh"
require_root
require_cmd useradd
for department in traffic safety water utilities; do
    getent group "$department" >/dev/null || die "Group $department is missing; run setup_departments.sh first."
done
for department in traffic safety water utilities; do
    user="${department}_demo"
    if getent passwd "$user" >/dev/null; then
        log "Account already exists; leaving it unchanged: $user"
        continue
    fi
    useradd --no-create-home --gid "$department" --shell /usr/sbin/nologin \
        --comment "Smart City demo account for $department" "$user"
    log "Created non-login demonstration account $user in group $department"
done
printf 'These accounts cannot log in interactively; use them to demonstrate group-based file permissions.\n'
