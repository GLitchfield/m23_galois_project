#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 6 ]]; then
  echo "usage: $0 PAIR_CHECKPOINT LIMIT FIRST_ORDINAL BLOCK_COUNT OUTPUT PROGRESS" >&2
  exit 2
fi

checkpoint=$1
limit=$2
first=$3
count=$4
output=$5
progress=$6
mkdir -p "$(dirname "$output")" "$(dirname "$progress")"
temporary="$(mktemp "$(dirname "$output")/.m23-macro-scan.XXXXXX")"
trap 'rm -f "$temporary"' EXIT

M23_PAIR_CHECKPOINT="$checkpoint" M23_ORBIT_LIMIT="$limit" \
M23_FIRST_ORDINAL="$first" M23_BLOCK_COUNT="$count" \
M23_OUTPUT="$temporary" M23_PROGRESS_FILE="$progress" \
  gap -q scripts/gap/scan_homogeneous_macroblocks.g
grep -q '^target_order' "$temporary"
mv "$temporary" "$output"
trap - EXIT
