#!/usr/bin/env bash
# purgeb.sh — purge build‑artifact directories like node_modules, Rust target, etc.
# Version: 2.2.0

set -euo pipefail
IFS=$'\n\t'

VERSION="2.2.0"
SCRIPT_NAME="${0##*/}"
KINDS=(node_modules) # default kinds
DRY_RUN=false
ASSUME_YES=false
QUIET=false
EXCLUDES=()
ROOT_DIR=""

show_help() {
  cat <<EOF
$SCRIPT_NAME $VERSION — delete bulky build artifacts (portable, Bash 3.2+)

Usage:
  $SCRIPT_NAME [OPTIONS] <PATH>

PATH (required):
  The root directory under which to search for build‑artifact folders.

Options:
  -k, --kind NAME        Directory name to purge (repeatable; default=node_modules)
  --rust                 Shortcut — adds "target" to kinds list
  -e, --exclude PATTERN  Glob pattern to keep (repeatable)
  -n, --dry-run          Preview deletions & freed space, no changes
  -y, --yes              Skip confirmation prompt
  -q, --quiet            Suppress per‑directory logs, keep final summary
  -v, --version          Show version and exit
  -h, --help             Show this help

Examples:
  # Preview node_modules purge under ~/project
  $SCRIPT_NAME -n ~/project

  # Purge node_modules + Rust targets except "infra" paths
  $SCRIPT_NAME --rust -e "*/infra/*" -y ~/project
EOF
}

format_size() {
  local kib=$1
  local units=(KiB MiB GiB TiB PiB) idx=0 size=$kib
  while ((size >= 1024 && idx < ${#units[@]} - 1)); do
    size=$((size / 1024))
    ((idx++))
  done
  printf '%s %s' "$size" "${units[$idx]}"
}

contains() { # $1 needle, rest haystack
  local item=$1
  shift || true
  for e in "$@"; do [[ $e == "$item" ]] && return 0; done
  return 1
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
    -k | --kind)
      [[ $# -lt 2 ]] && {
        echo "Missing name for --kind" >&2
        exit 1
      }
      KINDS+=("$2")
      shift
      ;;
    --rust) KINDS+=(target) ;;
    -e | --exclude)
      [[ $# -lt 2 ]] && {
        echo "Missing pattern for --exclude" >&2
        exit 1
      }
      EXCLUDES+=("$2")
      shift
      ;;
    -n | --dry-run) DRY_RUN=true ;;
    -y | --yes) ASSUME_YES=true ;;
    -q | --quiet) QUIET=true ;;
    -v | --version)
      echo "$VERSION"
      exit 0
      ;;
    -h | --help)
      show_help
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "Unknown option: $1" >&2
      show_help
      exit 1
      ;;
    *) ROOT_DIR="$1" ;;
    esac
    shift
  done
}

parse_args "$@"

if [[ -z "$ROOT_DIR" ]]; then
  echo "Error: PATH argument is required." >&2
  show_help
  exit 1
fi

UNIQ_KINDS=()
for k in "${KINDS[@]}"; do
  if ! contains "$k" "${UNIQ_KINDS[@]+"${UNIQ_KINDS[@]}"}"; then
    UNIQ_KINDS+=("$k")
  fi
done
KINDS=("${UNIQ_KINDS[@]}")

FIND_CMD=(find "$ROOT_DIR" \()
for i in "${!KINDS[@]}"; do
  FIND_CMD+=(-type d -name "${KINDS[$i]}")
  ((i < ${#KINDS[@]} - 1)) && FIND_CMD+=(-o)
done
FIND_CMD+=(\))
if ((${#EXCLUDES[@]})); then
  for pat in "${EXCLUDES[@]}"; do
    FIND_CMD+=(-not -path "*${pat}*")
  done
fi
FIND_CMD+=(-prune)

TEMP_FILE=$(mktemp)
trap 'rm -f "$TEMP_FILE"' EXIT
"${FIND_CMD[@]}" >"$TEMP_FILE"

TARGETS=()
while IFS= read -r dir; do
  [[ -n "$dir" ]] && TARGETS+=("$dir")
done <"$TEMP_FILE"

if [[ ${#TARGETS[@]} -eq 0 ]]; then
  $QUIET || echo "No matching directories found."
  exit 0
fi

TOTAL_HUMAN=$(du -shc "${TARGETS[@]}" | tail -1 | awk '{print $1}')

if ! $QUIET; then
  echo "Found ${#TARGETS[@]} directories (${KINDS[*]}):"
  echo
  du -sh "${TARGETS[@]}" | while read -r size path; do
    printf "%s\t%s\n" "$size" "$path"
  done
  echo
  echo "Total: $TOTAL_HUMAN"
fi

if $DRY_RUN; then
  $QUIET || echo "Dry run: would free $TOTAL_HUMAN."
  exit 0
fi

if ! $ASSUME_YES; then
  read -r -p "Continue? [y/N] " reply
  [[ ! $reply =~ ^[Yy]$ ]] && {
    $QUIET || echo "Aborted."
    exit 0
  }
fi

SECONDS=0
for d in "${TARGETS[@]}"; do
  rm -rf -- "$d"
  $QUIET || echo "Removed $d"
done
time_spent=$SECONDS

printf '\nPurged %d directories, freed %s in %ds.\n' \
  "${#TARGETS[@]}" "$TOTAL_HUMAN" "$time_spent"
