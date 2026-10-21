#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 12 ]]; then
  echo "usage: $0 PAIR_CHECKPOINT BASE_DB BASE_MANIFEST FIRST LAST START PROOF_LIMIT WALK_LIMIT RUN_DIR CERTIFICATE_JOBS BLOCK_JOBS SCHEDULE" >&2
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
certificate_jobs=$1
block_jobs=$2
schedule=$3
database="$run_dir/ledger.sqlite3"
progress="$run_dir/progress.tsv"
plan="$run_dir/parallel-certificate-plan.json"
min_available_mib=${M23_MIN_AVAILABLE_MIB:-8192}
[[ "$min_available_mib" =~ ^[0-9]+$ ]] || {
  echo "invalid nonnegative memory reserve: $min_available_mib" >&2
  exit 2
}
available_mib=$(awk '/^MemAvailable:/ { print int($2 / 1024) }' /proc/meminfo)
if (( available_mib < min_available_mib )); then
  echo "refusing to start quotient replay: ${available_mib} MiB available, ${min_available_mib} MiB required" >&2
  exit 75
fi

python3 scripts/plan_quotient_certificate_segments.py \
  "$database" "$base_manifest" "$certificate_jobs" "$plan"
read -r marker base_blocks base_certificates plan_id planned_jobs \
  <"${plan%.json}.tsv"
[[ "$marker" == M && "$planned_jobs" == "$certificate_jobs" ]] || {
  echo "invalid certificate segment plan metadata" >&2
  exit 1
}

pids=()
while IFS=$'\t' read -r kind index count first_certificate \
    last_certificate weight row_plan; do
  [[ "$kind" == S ]] || continue
  M23_PROGRESS_FILE="$progress" \
    ./scripts/verify-direct-pair-quotient-certificate-segment.sh \
    "$pair_checkpoint" "$database" "$first" "$last" "$proof_limit" \
    "$walk_limit" "$schedule" "$start" "$index" "$count" \
    "$first_certificate" "$last_certificate" "$row_plan" \
    >"$run_dir/certificate-segment-$index.log" 2>&1 &
  pids+=("$!")
done <"${plan%.json}.tsv"

for ((index = 1; index <= block_jobs; index++)); do
  M23_PROGRESS_FILE="$progress" \
    ./scripts/verify-direct-pair-quotient-block-segment.sh \
    "$pair_checkpoint" "$database" "$first" "$last" "$proof_limit" \
    "$walk_limit" "$schedule" "$start" "$index" "$block_jobs" \
    "$base_blocks" "$base_certificates" "$plan_id" \
    >"$run_dir/block-segment-$index.log" 2>&1 &
  pids+=("$!")
done

status=0
for pid in "${pids[@]}"; do
  if ! wait "$pid"; then status=1; fi
done
if (( status != 0 )); then
  echo "one or more parallel verification segments failed" >&2
  exit 1
fi

python3 scripts/finalize_parallel_quotient_verification.py \
  "$database" "$base_db" "$plan" "$progress" "$block_jobs" \
  "$run_dir/parallel-verification.json"
python3 scripts/m23_quotient_shards.py audit \
  "$base_db" "$base_manifest" "$run_dir" "$progress" \
  >"$run_dir/audit-parallel.json"
cat "$run_dir/audit-parallel.json"
