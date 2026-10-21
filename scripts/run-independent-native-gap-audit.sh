#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 5 ]]; then
  echo "usage: $0 LEDGER.sqlite3 PAIR_CHECKPOINT.g RUN_DIR JOBS LINKED_SAMPLES" >&2
  exit 2
fi

ledger=$(realpath "$1")
pair_checkpoint=$(realpath "$2")
run_dir=$3
jobs=$4
linked_samples=$5
exception_limit=${M23_EXCEPTION_LIMIT_PER_STATUS:-}
require_full_cursor=${M23_REQUIRE_FULL_CURSOR:-0}
block_samples=${M23_BLOCK_SAMPLES:-64}
for value in "$jobs" "$linked_samples"; do
  [[ "$value" =~ ^[0-9]+$ ]] || {
    echo "invalid independent GAP audit count: $value" >&2
    exit 2
  }
done
[[ "$block_samples" =~ ^[0-9]+$ ]] || {
  echo "invalid independent GAP block sample count" >&2
  exit 2
}
(( jobs > 0 )) || { echo "independent GAP audit needs a worker" >&2; exit 2; }
[[ -z "$exception_limit" || "$exception_limit" =~ ^[1-9][0-9]*$ ]] || {
  echo "invalid exceptional-certificate limit" >&2
  exit 2
}
[[ "$require_full_cursor" == 0 || "$require_full_cursor" == 1 ]] || {
  echo "M23_REQUIRE_FULL_CURSOR must be zero or one" >&2
  exit 2
}
[[ ! -e "$run_dir" ]] || {
  echo "refusing nonfresh independent GAP audit directory: $run_dir" >&2
  exit 2
}
mkdir -p "$run_dir"
echo "$$" >"$run_dir/runner.pid"
progress="$run_dir/progress.tsv"
touch "$progress"
revision=$(git rev-parse HEAD)
dirty=0
[[ -z "$(git status --short)" ]] || dirty=1
printf '%s\tgap\tverify_native_certificate_sample\tall\tstart\trevision=%s,dirty=%s,jobs=%s\n' \
  "$(date +%s)" "$revision" "$dirty" "$jobs" >>"$progress"

plan_args=(
  "$ledger" "$pair_checkpoint" "$run_dir/plan.tsv" "$run_dir/plan.json"
  --linked-samples "$linked_samples" --block-samples "$block_samples"
  --jobs "$jobs"
)
if [[ -n "$exception_limit" ]]; then
  plan_args+=(--exception-limit-per-status "$exception_limit")
fi
if [[ "$require_full_cursor" == 1 ]]; then
  plan_args+=(--require-full-cursor)
fi
python3 scripts/plan_independent_native_gap_audit.py "${plan_args[@]}" \
  >"$run_dir/planner.log"
plan_id=$(awk -F '\t' '$1 == "# plan_sha256" {print $2}' "$run_dir/plan.tsv")
selected=$(awk -F '\t' '$1 == "# selected_certificates" {print $2}' "$run_dir/plan.tsv")
selected_blocks=$(awk -F '\t' '$1 == "# selected_blocks" {print $2}' "$run_dir/plan.tsv")
[[ "$plan_id" =~ ^[0-9a-f]{64}$ && "$selected" =~ ^[0-9]+$ && \
   "$selected_blocks" =~ ^[0-9]+$ && \
   "$((selected + selected_blocks))" -gt 0 && \
   "$jobs" -le "$((selected + selected_blocks))" ]] || {
  echo "invalid independent GAP audit plan or excessive worker count" >&2
  exit 1
}

sampler_pid=0
pids=()
cleanup() {
  local status=$?
  trap - EXIT INT TERM
  for pid in "${pids[@]:-}" "$sampler_pid"; do
    if [[ "$pid" =~ ^[1-9][0-9]*$ ]]; then
      kill "$pid" 2>/dev/null || true
    fi
  done
  for pid in "${pids[@]:-}" "$sampler_pid"; do
    if [[ "$pid" =~ ^[1-9][0-9]*$ ]]; then
      wait "$pid" 2>/dev/null || true
    fi
  done
  if (( status != 0 )); then
    printf '%s\tgap\tverify_native_certificate_sample\tall\tfailed\texit=%s\n' \
      "$(date +%s)" "$status" >>"$progress"
  fi
  exit "$status"
}
trap cleanup EXIT INT TERM

python3 scripts/sample_process_trees.py "$run_dir/resources.tsv" \
  "$$" --labels gap --interval 5 &
sampler_pid=$!
for ((segment = 1; segment <= jobs; segment++)); do
  M23_PAIR_CHECKPOINT="$pair_checkpoint" M23_LEDGER_DB="$ledger" \
  M23_AUDIT_PLAN="$(realpath "$run_dir/plan.tsv")" \
  M23_AUDIT_PLAN_ID="$plan_id" \
  M23_AUDIT_RESULT="$(realpath -m "$run_dir/segment-$segment.tsv")" \
  M23_PROGRESS_FILE="$(realpath "$progress")" \
  M23_SEGMENT_INDEX="$segment" M23_SEGMENT_COUNT="$jobs" \
    gap --quitonbreak -q scripts/gap/verify_native_certificate_sample.g \
    >"$run_dir/segment-$segment.log" 2>&1 &
  pids+=("$!")
done
status=0
for pid in "${pids[@]}"; do
  if ! wait "$pid"; then status=1; fi
done
(( status == 0 )) || {
  echo "one or more independent GAP audit workers failed" >&2
  exit 1
}
pids=()
results=()
for ((segment = 1; segment <= jobs; segment++)); do
  results+=("$run_dir/segment-$segment.tsv")
done
python3 scripts/finalize_independent_native_gap_audit.py \
  "$ledger" "$run_dir/plan.tsv" "$run_dir/result.json" "${results[@]}" \
  >"$run_dir/finalizer.log"
printf '%s\tgap\tverify_native_certificate_sample\tall\tdone\tplan=%s,certificates=%s,blocks=%s\n' \
  "$(date +%s)" "$plan_id" "$selected" "$selected_blocks" >>"$progress"
kill "$sampler_pid" 2>/dev/null || true
wait "$sampler_pid" 2>/dev/null || true
sampler_pid=0
trap - EXIT INT TERM
cat "$run_dir/result.json"
