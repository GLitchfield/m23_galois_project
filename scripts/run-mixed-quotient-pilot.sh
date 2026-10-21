#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 16 ]]; then
  echo "usage: $0 PAIR BASE_DB BASE_MANIFEST CANDIDATE_DIR LIVE_DIR FIRST LAST START PROOF WALK SCAN_WORKERS VIRTUAL_SHARDS TARGET CERTIFICATE_JOBS BLOCK_JOBS TRAVERSAL_ORDER" >&2
  exit 2
fi

pair_checkpoint=$1
base_db=$2
base_manifest=$3
candidate_dir=$4
live_dir=$5
first=$6
last=$7
start=$8
proof_limit=$9
shift 9
walk_limit=$1
scan_workers=$2
virtual_shards=$3
target=$4
certificate_jobs=$5
block_jobs=$6
traversal_order=$7
sample_seconds=${M23_RESOURCE_SAMPLE_SECONDS:-5}

for value in "$first" "$last" "$start" "$proof_limit" "$walk_limit" \
    "$scan_workers" "$virtual_shards" "$target" "$certificate_jobs" \
    "$block_jobs" "$sample_seconds"; do
  [[ "$value" =~ ^[1-9][0-9]*$ ]] || {
    echo "invalid positive integer: $value" >&2
    exit 2
  }
done
[[ "$traversal_order" == legacy || "$traversal_order" == key-v1 || \
  "$traversal_order" == key-v2 ]] || {
  echo "invalid traversal order" >&2
  exit 2
}
[[ -s "$candidate_dir/ledger.sqlite3" && \
   -s "$candidate_dir/shards.json" && \
   -s "$live_dir/ledger.sqlite3" && -s "$live_dir/shards.json" ]] || {
  echo "candidate and live run directories must already be prepared" >&2
  exit 2
}

M23_MIN_AVAILABLE_MIB=${M23_MIN_AVAILABLE_MIB:-12288} \
  ./scripts/run-parallel-quotient-delta-verification.sh \
  "$pair_checkpoint" "$base_db" "$base_manifest" \
  "$first" "$last" "$start" "$proof_limit" "$walk_limit" \
  "$candidate_dir" "$certificate_jobs" "$block_jobs" frontier \
  >"$candidate_dir/mixed-replay.log" 2>&1 &
replay_pid=$!

M23_MIN_AVAILABLE_MIB=${M23_MIN_AVAILABLE_MIB:-12288} \
M23_DETERMINISTIC_SHARDS=dynamic M23_VIRTUAL_SHARDS="$virtual_shards" \
M23_TRAVERSAL_ORDER="$traversal_order" \
  ./scripts/run-db-quotient-workers.sh "$pair_checkpoint" \
  "$first" "$last" "$start" "$proof_limit" "$walk_limit" \
  "$live_dir" "$scan_workers" "$target" \
  >"$live_dir/mixed-scan.log" 2>&1 &
scan_pid=$!

python3 scripts/sample_process_trees.py \
  "$live_dir/mixed-resource-samples-to-$target.tsv" \
  "$replay_pid" "$scan_pid" --labels replay scan \
  --interval "$sample_seconds" &
sample_pid=$!

status=0
if ! wait "$replay_pid"; then status=1; fi
if ! wait "$scan_pid"; then status=1; fi
if ! wait "$sample_pid"; then status=1; fi
if (( status != 0 )); then
  echo "mixed quotient pilot failed; inspect candidate/live logs" >&2
  exit 1
fi

echo "mixed quotient pilot completed at live target $target"
