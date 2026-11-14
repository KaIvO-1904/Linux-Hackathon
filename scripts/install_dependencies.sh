#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_root
[[ -r /etc/os-release ]] || die "Cannot identify this operating system."
# shellcheck disable=SC1091
source /etc/os-release
[[ ${ID:-} == ubuntu ]] || die "This installer is intended for the Ubuntu Server VM, not Kali WSL."

export DEBIAN_FRONTEND=noninteractive
log "Refreshing Ubuntu package metadata."
apt-get update
log "Installing project dependencies."
apt-get install -y rsyslog cron ufw tar gzip rsync procps util-linux coreutils lvm2 e2fsprogs python3 acl
log "Dependencies installed. Enable/configure services in the runbook when appropriate."
