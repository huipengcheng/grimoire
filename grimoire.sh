#!/usr/bin/env bash
# grimoire.sh — entry point. Dispatches to scripts/grimoire-<command>.
#
# Usage:
#   ./grimoire.sh install [args...]   Deploy grimoire content to assistant config dirs.
#   ./grimoire.sh doctor              Diagnose local config, conflicts, orphan symlinks.
#   ./grimoire.sh <command> --help    Per-command help where supported.

set -euo pipefail
GRIMOIRE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'
  printf '\nAvailable commands:\n'
  local f base
  for f in "$GRIMOIRE_DIR"/scripts/grimoire-*; do
    [[ -x "$f" ]] || continue
    base=$(basename "$f")
    printf '  %s\n' "${base#grimoire-}"
  done
}

cmd=${1-}
case "$cmd" in
  ""|-h|--help) usage; exit 0 ;;
esac
shift

script="$GRIMOIRE_DIR/scripts/grimoire-$cmd"
if [[ ! -x "$script" ]]; then
  printf 'unknown command: %s\n\n' "$cmd" >&2
  usage >&2
  exit 1
fi
exec "$script" "$@"
