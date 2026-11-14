#!/usr/bin/env bash
set -Eeuo pipefail

readonly LOG_ROOT=/srv/smartcity/logs
declare -A EXPECTED=(
    [traffic]=smartcity-traffic
    [safety]=smartcity-safety
    [water]=smartcity-water
    [utilities]=smartcity-utilities
)
failures=0
for department in traffic safety water utilities; do
    file="$LOG_ROOT/$department/$department.log"
    if [[ -s "$file" ]] && tail -n 50 -- "$file" | grep -Fq -- "${EXPECTED[$department]}"; then
        printf 'PASS %-10s %s\n' "$department" "$file"
        tail -n 2 -- "$file" | sed 's/^/  /'
    else
        printf 'FAIL %-10s no recent tagged message in %s\n' "$department" "$file"
        failures=$((failures + 1))
    fi
done
(( failures == 0 )) || exit 1
