#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 8 ]]; then
  echo "usage: $0 PAIR_CHECKPOINT FIRST_ORDINAL LAST_ORDINAL START_ORDINAL PROOF_LIMIT WALK_LIMIT RUN_DIR BLOCK_BUDGET" >&2
  exit 2
fi

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
pair_checkpoint=$1
first=$2
last=$3
start=$4
proof_limit=$5
walk_limit=$6
run_dir=$7
block_budget=$8

mkdir -p "$run_dir"
pair_checkpoint=$(realpath "$pair_checkpoint")
run_dir=$(realpath "$run_dir")
progress_file="$run_dir/progress.tsv"
database="$run_dir/ledger.sqlite3"

event() {
  printf '%s\tshell\tverify_quotient_queue\tall\t%s\t%s\n' \
    "$(date +%s)" "$1" "$2" >>"$progress_file"
}

echo "$$" >"$run_dir/runner.pid"
cd "$repo_root"
event start "block_budget=$block_budget,proof_limit=$proof_limit,walk_limit=$walk_limit"

if ! ./scripts/verify-direct-pair-quotient-db.sh \
    "$pair_checkpoint" "$database" "$first" "$last" "$proof_limit" \
    "$walk_limit" frontier "$start"; then
  event failed "stage=pre_extension_replay"
  exit 1
fi
event progress "stage=pre_extension_replay_passed"

if ! ./scripts/scan-direct-pair-quotient-db.sh \
    "$pair_checkpoint" "$first" "$last" "$proof_limit" "$run_dir" \
    frontier "$start" "$block_budget" "$walk_limit"; then
  event failed "stage=extension_scan"
  exit 1
fi
event progress "stage=extension_scan_passed"

if ! ./scripts/verify-direct-pair-quotient-db.sh \
    "$pair_checkpoint" "$database" "$first" "$last" "$proof_limit" \
    "$walk_limit" frontier "$start"; then
  event failed "stage=post_extension_replay"
  exit 1
fi
event done "stage=post_extension_replay_passed"
