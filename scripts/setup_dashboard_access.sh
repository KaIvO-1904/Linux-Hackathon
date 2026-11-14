#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_root
require_cmd getent
require_cmd setfacl
readonly DASHBOARD_USER=smartcity-dashboard
readonly LOG_ROOT=/srv/smartcity/logs

if ! getent passwd "$DASHBOARD_USER" >/dev/null; then
    useradd --system --user-group --home-dir /nonexistent --no-create-home --shell /usr/sbin/nologin "$DASHBOARD_USER"
    log "Created unprivileged dashboard account: $DASHBOARD_USER"
else
    existing_shell=$(getent passwd "$DASHBOARD_USER" | cut -d: -f7)
    [[ $existing_shell == /usr/sbin/nologin ]] || die "Refusing to use existing $DASHBOARD_USER account with shell $existing_shell. Review it manually."
fi

for department in traffic safety water utilities; do
    directory="$LOG_ROOT/$department"
    [[ -d $directory ]] || die "Missing $directory. Run setup_departments.sh first."
    # Named-user ACLs grant traversal/read only; this account is not added to
    # the department groups and therefore cannot write into their directories.
    setfacl -m "u:$DASHBOARD_USER:r-x" "$directory"
    setfacl -m "d:u:$DASHBOARD_USER:r-x" "$directory"
    logfile="$directory/$department.log"
    [[ ! -f $logfile ]] || setfacl -m "u:$DASHBOARD_USER:r--" "$logfile"
done

log "Dashboard account can read routed department logs through ACLs; it has no department-group membership or log-write permission."
