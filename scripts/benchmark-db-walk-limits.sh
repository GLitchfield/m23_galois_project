#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "usage: $0 PAIR_CHECKPOINT BLOCK_BUDGET RUN_ROOT" >&2
  exit 2
fi

pair_checkpoint=$1
block_budget=$2
run_root=$3
[[ -s "$pair_checkpoint" ]] || { echo "missing pair checkpoint" >&2; exit 2; }
[[ "$block_budget" =~ ^[1-9][0-9]*$ ]] || { echo "invalid block budget" >&2; exit 2; }
mkdir -p "$run_root"

for walk_limit in 2500 10000 25000; do
  run_dir="$run_root/walk-$walk_limit"
  if [[ -e "$run_dir/ledger.sqlite3" ]]; then
    echo "refusing to reuse benchmark database: $run_dir/ledger.sqlite3" >&2
    exit 1
  fi
  ./scripts/scan-direct-pair-quotient-db.sh "$pair_checkpoint" \
    2 7928185 2500 "$run_dir" frontier 1633430 "$block_budget" "$walk_limit"
done

python3 scripts/summarize_db_walk_limits.py "$run_root" | tee "$run_root/summary.tsv"
