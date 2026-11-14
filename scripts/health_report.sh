#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

usage() {
    printf 'Usage: %s [--output FILE]\n' "$(basename -- "$0")"
}

output_file=""
while (($#)); do
    case "$1" in
        --output)
            (($# >= 2)) || { usage >&2; exit 2; }
            output_file=$2
            shift 2
            ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; die "Unknown argument: $1" ;;
    esac
done

cpu_sample() {
    # Linux exposes guest/guest_nice as subsets of user/nice; exclude those
    # duplicate counters from the total to avoid understating utilization.
    awk '/^cpu / { total=0; for (i=2; i<=9; i++) total += $i; idle=$5+$6; printf "%.0f %.0f\n", total, idle; exit }' /proc/stat
}

generate_report() {
    local total1 idle1 total2 idle2 cpu_percent memory_line load_line service
    read -r total1 idle1 < <(cpu_sample)
    sleep 1
    read -r total2 idle2 < <(cpu_sample)
    cpu_percent=$(awk -v t1="$total1" -v i1="$idle1" -v t2="$total2" -v i2="$idle2" \
        'BEGIN { dt=t2-t1; di=i2-i1; if (dt <= 0) print "unavailable"; else printf "%.1f%%", 100*(dt-di)/dt }')
    memory_line=$(free -b | awk 'NR==2 { if ($2 > 0) printf "%.1f%% used (%s of %s bytes)", 100*$3/$2, $3, $2; else print "unavailable" }')
    load_line=$(awk '{print $1 ", " $2 ", " $3}' /proc/loadavg)

    printf 'Smart City Command Centre — System Health\n'
    printf 'Generated: %s\n' "$(date --iso-8601=seconds)"
    printf 'Hostname:  %s\n' "$(hostname)"
    printf '\nCPU utilization (1-second sample): %s\n' "$cpu_percent"
    printf 'Load averages (1, 5, 15 min): %s\n' "$load_line"
    printf 'Memory: %s\n' "$memory_line"
    printf '\nRoot filesystem:\n'
    df -hP / | awk 'NR==1 || NR==2 {print}'
    if [[ -d /srv/smartcity ]]; then
        printf '\nProject data filesystem:\n'
        df -hP /srv/smartcity | awk 'NR==1 || NR==2 {print}'
    fi
    printf '\nUptime: '
    uptime -p
    printf '\nKey services:\n'
    for service in rsyslog cron ssh; do
        if systemctl is-active --quiet "$service"; then
            printf '  %-10s active\n' "$service"
        else
            printf '  %-10s inactive or unavailable\n' "$service"
        fi
    done
    printf '\nLogged-in users:\n'
    who || true
}

if [[ -n $output_file ]]; then
    install -d -m 0755 "$(dirname -- "$output_file")"
    generate_report | tee "$output_file"
else
    generate_report
fi
