#!/usr/bin/env bash
set -Eeuo pipefail

command -v logger >/dev/null 2>&1 || { printf 'logger is required (provided by util-linux on Ubuntu).\n' >&2; exit 1; }
stamp=$(date --iso-8601=seconds)
logger -p local0.info -t smartcity-traffic -- "[$stamp] Traffic department: intersection sensor status normal"
logger -p local1.notice -t smartcity-safety -- "[$stamp] Public safety department: patrol dispatch system online"
logger -p local2.info -t smartcity-water -- "[$stamp] Water department: reservoir telemetry received"
logger -p local3.info -t smartcity-utilities -- "[$stamp] Utilities department: power grid status normal"
printf 'Sent four local sample messages. Check routing with verify_logs.sh.\n'
