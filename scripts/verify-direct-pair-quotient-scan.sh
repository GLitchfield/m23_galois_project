#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 PAIR_CHECKPOINT SCAN_CHECKPOINT" >&2
  exit 2
fi

pair_checkpoint=$1
scan_checkpoint=$2
[[ -s "$pair_checkpoint" ]] || { echo "missing pair checkpoint: $pair_checkpoint" >&2; exit 2; }
[[ -s "$scan_checkpoint" ]] || { echo "missing scan checkpoint: $scan_checkpoint" >&2; exit 2; }

progress_file=${M23_PROGRESS_FILE:-$(dirname "$(realpath "$scan_checkpoint")")/progress.tsv}
M23_PAIR_CHECKPOINT=$(realpath "$pair_checkpoint") \
M23_SCAN_CHECKPOINT=$(realpath "$scan_checkpoint") \
M23_PROGRESS_FILE="$progress_file" \
  gap --quitonbreak -q scripts/gap/verify_direct_pair_quotient_scan.g
