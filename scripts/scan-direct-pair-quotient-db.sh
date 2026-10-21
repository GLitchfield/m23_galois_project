#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 5 || $# -gt 9 ]]; then
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
for value in "$first_ordinal" "$last_ordinal" "$limit" "$start_ordinal" "$block_budget" "$walk_limit"; do
  [[ "$value" =~ ^[1-9][0-9]*$ ]] || { echo "invalid positive integer: $value" >&2; exit 2; }
done
[[ "$schedule" == sequential || "$schedule" == frontier ]] || { echo "invalid schedule" >&2; exit 2; }
(( walk_limit >= limit )) || { echo "walk limit must be at least the proof limit" >&2; exit 2; }

mkdir -p "$run_dir"
pair_checkpoint=$(realpath "$pair_checkpoint")
run_dir=$(realpath "$run_dir")
export M23_PAIR_CHECKPOINT="$pair_checkpoint"
export M23_FIRST_ORDINAL="$first_ordinal"
export M23_LAST_ORDINAL="$last_ordinal"
export M23_ORBIT_LIMIT="$limit"
export M23_WALK_LIMIT="$walk_limit"
export M23_SCAN_SCHEDULE="$schedule"
export M23_START_ORDINAL="$start_ordinal"
export M23_BLOCK_BUDGET="$block_budget"
export M23_LEDGER_DB="$run_dir/ledger.sqlite3"
export M23_PROGRESS_FILE="$run_dir/progress.tsv"

gap --quitonbreak -q scripts/gap/scan_direct_pair_quotient_db.g
