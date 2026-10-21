#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 5 ]]; then
  echo "usage: $0 CLASS_ORDER SHARD_COUNT RUN_DIR RESULT_OUTPUT CERTIFICATE_OUTPUT" >&2
  exit 2
fi

class_order=$1
shard_count=$2
run_dir=$3
result_output=$4
certificate_output=$5
jobs=${M23_JOBS:-1}

[[ "$shard_count" =~ ^[1-9][0-9]*$ ]] || { echo "invalid shard count" >&2; exit 2; }
[[ "$jobs" =~ ^[1-9][0-9]*$ ]] || { echo "invalid M23_JOBS" >&2; exit 2; }
mkdir -p "$run_dir"
progress_file=${M23_PROGRESS_FILE:-$run_dir/progress.tsv}
export M23_PROGRESS_FILE="$progress_file"

event() {
  printf '%s\tshell\t%s\t%s\t%s\t%s\n' \
    "$(date +%s)" "$1" "$2" "$3" "$4" >>"$progress_file"
}

run_finished=false
on_exit() {
  status=$?
  if [[ "$run_finished" != true && $status -ne 0 ]]; then
    event run all failed "exit=$status"
  fi
}
trap on_exit EXIT
event run all start "class=$class_order,shards=$shard_count,jobs=$jobs"

run_batch() {
  local pid status=0
  for pid in "$@"; do
    if ! wait "$pid"; then
      status=1
    fi
  done
  return "$status"
}

pids=()
for ((index = 1; index <= shard_count; index++)); do
  checkpoint="$run_dir/shard-${index}-of-${shard_count}.g"
  if [[ -s "$checkpoint" ]]; then
    echo "resume: keeping $checkpoint"
    event shard "$index" reused "$checkpoint"
    continue
  fi
  (
    event shard "$index" start "$checkpoint"
    if ./scripts/run-cc2a2a-shard.sh \
      "$class_order" "$shard_count" "$index" "$checkpoint"; then
      event shard "$index" done "$checkpoint"
    else
      status=$?
      event shard "$index" failed "exit=$status"
      exit "$status"
    fi
  ) &
  pids+=("$!")
  if (( ${#pids[@]} >= jobs )); then
    run_batch "${pids[@]}"
    pids=()
  fi
done
if (( ${#pids[@]} > 0 )); then
  run_batch "${pids[@]}"
fi

event verify all start "$run_dir/certificate.tsv"
./scripts/verify-cc2a2a-shards.sh \
  "$class_order" "$shard_count" "$run_dir" "$run_dir/certificate.tsv"
event verify all done "$run_dir/certificate.tsv"
event merge all start "$run_dir/result.tsv"
./scripts/merge-cc2a2a-shards.sh \
  "$class_order" "$shard_count" "$run_dir" "$run_dir/result.tsv"
event merge all done "$run_dir/result.tsv"

(
  cd "$run_dir"
  sha256sum shard-*.g certificate.tsv result.tsv >SHA256SUMS
)
mkdir -p "$(dirname "$result_output")" "$(dirname "$certificate_output")"
cp "$run_dir/result.tsv" "$result_output"
cp "$run_dir/certificate.tsv" "$certificate_output"
event run all done "result=$result_output,certificate=$certificate_output"
run_finished=true
