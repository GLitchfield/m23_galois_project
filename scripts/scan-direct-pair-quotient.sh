#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 5 && $# -ne 8 && $# -ne 9 ]]; then
  echo "usage: $0 PAIR_CHECKPOINT FIRST_ORDINAL LAST_ORDINAL LIMIT RUN_DIR [SCHEDULE START_ORDINAL BLOCK_BUDGET [WALK_LIMIT]]" >&2
  exit 2
fi

pair_checkpoint=$1
first_ordinal=$2
last_ordinal=$3
limit=$4
run_dir=$5
schedule=${6:-sequential}
start_ordinal=${7:-$first_ordinal}
block_budget=${8:-$((last_ordinal - first_ordinal + 1))}
walk_limit=${9:-$limit}

[[ -s "$pair_checkpoint" ]] || { echo "missing pair checkpoint: $pair_checkpoint" >&2; exit 2; }
[[ "$first_ordinal" =~ ^[1-9][0-9]*$ ]] || { echo "invalid first ordinal" >&2; exit 2; }
[[ "$last_ordinal" =~ ^[1-9][0-9]*$ ]] || { echo "invalid last ordinal" >&2; exit 2; }
[[ "$limit" =~ ^[1-9][0-9]*$ ]] || { echo "invalid limit" >&2; exit 2; }
[[ "$schedule" == sequential || "$schedule" == frontier ]] || { echo "invalid schedule" >&2; exit 2; }
[[ "$start_ordinal" =~ ^[1-9][0-9]*$ ]] || { echo "invalid start ordinal" >&2; exit 2; }
[[ "$block_budget" =~ ^[1-9][0-9]*$ ]] || { echo "invalid block budget" >&2; exit 2; }
[[ "$walk_limit" =~ ^[1-9][0-9]*$ ]] || { echo "invalid walk limit" >&2; exit 2; }
(( walk_limit >= limit )) || { echo "walk limit must be at least the proof limit" >&2; exit 2; }
mkdir -p "$run_dir"
pair_checkpoint=$(realpath "$pair_checkpoint")
run_dir=$(realpath "$run_dir")

export M23_PAIR_CHECKPOINT="$pair_checkpoint"
export M23_FIRST_ORDINAL="$first_ordinal"
export M23_LAST_ORDINAL="$last_ordinal"
export M23_ORBIT_LIMIT="$limit"
export M23_SCAN_CHECKPOINT="$run_dir/scan.g"
export M23_PROGRESS_FILE="$run_dir/progress.tsv"
export M23_SCAN_SCHEDULE="$schedule"
export M23_START_ORDINAL="$start_ordinal"
export M23_BLOCK_BUDGET="$block_budget"
export M23_WALK_LIMIT="$walk_limit"

gap --quitonbreak -q scripts/gap/scan_direct_pair_quotient.g
