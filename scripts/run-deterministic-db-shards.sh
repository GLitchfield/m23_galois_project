#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 11 ]]; then
  echo "usage: $0 PAIR_CHECKPOINT BASE_DB BASE_MANIFEST FIRST LAST START PROOF_LIMIT WALK_LIMIT RUN_DIR SHARDS TARGET_BLOCKS" >&2
  exit 2
fi

pair_checkpoint=$1
base_db=$2
base_manifest=$3
first=$4
last=$5
start=$6
proof_limit=$7
walk_limit=$8
run_dir=$9
shift 9
shards=$1
target=$2
certificate_jobs=${M23_PARALLEL_CERTIFICATE_JOBS:-0}
block_jobs=${M23_PARALLEL_BLOCK_JOBS:-4}
[[ "$certificate_jobs" =~ ^[0-9]+$ && "$block_jobs" =~ ^[1-9][0-9]*$ ]] || {
  echo "invalid parallel verification job count" >&2
  exit 2
}

python3 scripts/m23_quotient_shards.py prepare \
  "$base_db" "$base_manifest" "$run_dir" "$shards" "$target"
M23_DETERMINISTIC_SHARDS=dynamic M23_VIRTUAL_SHARDS="$shards" \
  ./scripts/run-db-quotient-workers.sh \
  "$pair_checkpoint" "$first" "$last" "$start" "$proof_limit" \
  "$walk_limit" "$run_dir" "$shards" "$target"
if (( certificate_jobs > 0 )); then
  ./scripts/run-parallel-quotient-delta-verification.sh \
    "$pair_checkpoint" "$base_db" "$base_manifest" "$first" "$last" \
    "$start" "$proof_limit" "$walk_limit" "$run_dir" \
    "$certificate_jobs" "$block_jobs" frontier
else
  M23_PROGRESS_FILE="$run_dir/progress.tsv" \
    ./scripts/verify-direct-pair-quotient-db-delta.sh "$pair_checkpoint" \
    "$base_db" "$run_dir/ledger.sqlite3" "$first" "$last" \
    "$proof_limit" "$walk_limit" frontier "$start"
  python3 scripts/m23_quotient_shards.py audit \
    "$base_db" "$base_manifest" "$run_dir" "$run_dir/progress.tsv" \
    >"$run_dir/audit.json"
  cat "$run_dir/audit.json"
fi
