#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 17 ]]; then
  echo "usage: $0 PAIR_CHECKPOINT PRIOR_BASE_DB PRIOR_BASE_MANIFEST LIVE_DIR CURRENT_TARGET CANDIDATE_DIR VERIFIED_BASE_DIR NEXT_TARGET FIRST LAST START PROOF_LIMIT WALK_LIMIT SCAN_WORKERS CERTIFICATE_JOBS BLOCK_JOBS TRAVERSAL_ORDER" >&2
  exit 2
fi

pair_checkpoint=$1
prior_base_db=$2
prior_base_manifest=$3
live_dir=$4
current_target=$5
candidate_dir=$6
verified_base_dir=$7
next_target=$8
first=$9
shift 9
last=$1
start=$2
proof_limit=$3
walk_limit=$4
scan_workers=$5
certificate_jobs=$6
block_jobs=$7
traversal_order=$8
sample_seconds=${M23_RESOURCE_SAMPLE_SECONDS:-5}

for value in "$current_target" "$next_target" "$first" "$last" "$start" \
    "$proof_limit" "$walk_limit" "$scan_workers" "$certificate_jobs" \
    "$block_jobs"; do
  [[ "$value" =~ ^[1-9][0-9]*$ ]] || {
    echo "invalid positive integer: $value" >&2
    exit 2
  }
done
[[ "$traversal_order" == legacy || "$traversal_order" == key-v1 || \
  "$traversal_order" == key-v2 ]] || {
  echo "invalid traversal order: $traversal_order" >&2
  exit 2
}
[[ "$sample_seconds" =~ ^[1-9][0-9]*$ ]] || {
  echo "invalid positive resource sample interval" >&2
  exit 2
}
(( next_target > current_target )) || {
  echo "next target must exceed the candidate boundary" >&2
  exit 2
}

python3 scripts/freeze_quotient_candidate.py \
  "$live_dir/ledger.sqlite3" "$live_dir/progress.tsv" \
  "$live_dir/shards.json" "$candidate_dir" "$current_target"

M23_TRAVERSAL_ORDER="$traversal_order" \
  ./scripts/run-parallel-quotient-delta-verification.sh \
  "$pair_checkpoint" "$prior_base_db" "$prior_base_manifest" \
  "$first" "$last" "$start" "$proof_limit" "$walk_limit" \
  "$candidate_dir" "$certificate_jobs" "$block_jobs" frontier \
  >"$candidate_dir/verification-runner.log" 2>&1 &
verify_pid=$!
echo "$verify_pid" >"$candidate_dir/runner.pid"

M23_DETERMINISTIC_SHARDS=dynamic M23_VIRTUAL_SHARDS="$scan_workers" \
M23_TRAVERSAL_ORDER="$traversal_order" \
  ./scripts/run-db-quotient-workers.sh "$pair_checkpoint" \
  "$first" "$last" "$start" "$proof_limit" "$walk_limit" \
  "$live_dir" "$scan_workers" "$next_target" \
  >"$live_dir/scan-to-$next_target.log" 2>&1 &
scan_pid=$!
echo "$scan_pid" >"$live_dir/runner.pid"

python3 scripts/sample_process_trees.py \
  "$live_dir/resource-samples-to-$next_target.tsv" \
  "$verify_pid" "$scan_pid" --labels replay scan \
  --interval "$sample_seconds" &
sample_pid=$!

status=0
if ! wait "$verify_pid"; then status=1; fi
if ! wait "$scan_pid"; then status=1; fi
if ! wait "$sample_pid"; then status=1; fi
if (( status != 0 )); then
  echo "pipelined verification or speculative scan failed" >&2
  exit 1
fi

python3 scripts/snapshot_quotient_ledger.py \
  "$candidate_dir/ledger.sqlite3" "$verified_base_dir/ledger.sqlite3" \
  "$verified_base_dir/manifest.json" "$candidate_dir/progress.tsv"
python3 scripts/m23_quotient_shards.py retarget \
  "$verified_base_dir/ledger.sqlite3" "$verified_base_dir/manifest.json" \
  "$live_dir" "$scan_workers" "$next_target"

echo "verified $current_target blocks while scanning live ledger to $next_target"
