#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

usage() {
    printf 'Usage: %s --archive FILE --target EMPTY_DIRECTORY\n' "$(basename -- "$0")"
}

archive=""
target=""
while (($#)); do
    case "$1" in
        --archive) (($# >= 2)) || { usage >&2; exit 2; }; archive=$2; shift 2 ;;
        --target) (($# >= 2)) || { usage >&2; exit 2; }; target=$2; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; die "Unknown argument: $1" ;;
    esac
done
[[ -n $archive && -n $target ]] || { usage >&2; exit 2; }
[[ -f $archive ]] || die "Backup archive not found: $archive"
[[ $target == /* && $target != / ]] || die "Restore target must be an absolute path other than /."
[[ ! -L $target ]] || die "Restore target must not be a symbolic link: $target"
require_cmd tar
require_root

members=$(mktemp)
trap 'rm -f -- "$members"' EXIT
tar --list --gzip --file="$archive" > "$members" || die "Cannot list archive contents."
while IFS= read -r member; do
    [[ $member != /* ]] || die "Refusing archive with an absolute path: $member"
    [[ ! $member =~ (^|/)\.\.(/|$) ]] || die "Refusing archive with a parent-directory path: $member"
done < "$members"

if [[ -e $target ]]; then
    [[ -d $target ]] || die "Target exists and is not a directory: $target"
    [[ -z $(find "$target" -mindepth 1 -maxdepth 1 -print -quit) ]] || die "Target must be empty: $target"
else
    install -d -m 0700 "$target"
fi
tar --extract --gzip --file="$archive" --directory="$target" --no-same-owner --no-same-permissions
log "Restored archive into $target. Inspect the contents before using them."
