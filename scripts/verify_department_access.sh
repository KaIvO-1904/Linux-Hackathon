#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/lib/common.sh"
require_root
require_cmd runuser
declare -A PROBES=()
cleanup() {
    for probe in "${PROBES[@]}"; do rm -f -- "$probe"; done
}
trap cleanup EXIT
failures=0
for department in traffic safety water utilities; do
    allowed_user="${department}_demo"
    dir="/srv/smartcity/logs/$department"
    [[ -d $dir ]] || die "Department directory not found: $dir"
    getent passwd "$allowed_user" >/dev/null || die "Run create_demo_accounts.sh first; missing $allowed_user"
    probe="$dir/.access-check-$$"
    PROBES["$department"]=$probe
    if runuser -u "$allowed_user" -- touch "$probe" 2>/dev/null; then
        printf 'PASS %-10s %s can write to its own folder\n' "$department" "$allowed_user"
    else
        printf 'FAIL %-10s %s could not write to its own folder\n' "$department" "$allowed_user"
        failures=$((failures + 1))
    fi
    for other in traffic safety water utilities; do
        [[ $other == "$department" ]] && continue
        other_user="${other}_demo"
        if runuser -u "$other_user" -- test -x "$dir" 2>/dev/null; then
            printf 'FAIL %-10s %s can enter another department folder\n' "$department" "$other_user"
            failures=$((failures + 1))
        fi
    done
done
(( failures == 0 )) || exit 1
printf 'PASS Department access isolation checks completed.\n'
