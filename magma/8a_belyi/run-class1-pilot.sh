#!/usr/bin/env bash
set -uo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 BELYI_CHECKOUT NEW_OUTPUT_DIRECTORY" >&2
  exit 2
fi

belyi_checkout=$1
output_dir=$2
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
project_root=$(cd "$script_dir/../.." && pwd)
input_file=${M23_PILOT_INPUT_FILE:-$project_root/data/derived/m23_8a_8a_2a_belyi_input.m}
pilot_file=${M23_PILOT_BODY_FILE:-$script_dir/class1_pilot.m}
entrypoint_file=${M23_PILOT_ENTRYPOINT_FILE:-$script_dir/run-class1-pilot.sh}
extractor="$project_root/scripts/extract_magma_belyi_candidate.py"
verifier="$project_root/scripts/verify_belyi_candidate.py"
schema="$project_root/data/schema/belyi_candidate_v1.schema.json"

pinned_belyi_revision=f6f78dc2950343fcd9894c334f9a58f3ab065843
pinned_input_sha256=${M23_PILOT_INPUT_SHA256:-9321892c1ce8e8e1a27b9351bae77d1229b59d5d26cdb96fcaf5c5999d7bff8c}
class_min=${M23_PILOT_CLASS_MIN:-1}
class_max=${M23_PILOT_CLASS_MAX:-28}
candidate_problem_id=${M23_PILOT_PROBLEM_ID:-m23-8a-8a-2a-degree23}
candidate_partitions_json=${M23_PILOT_PARTITIONS_JSON:-'[[8,8,4,2,1],[8,8,4,2,1],[2,2,2,2,2,2,2,2,1,1,1,1,1,1,1]]'}
candidate_source_description=${M23_PILOT_SOURCE_DESCRIPTION:-"class %s of the committed (8A,8A,2A) inner-class certificate"}
candidate_source_dataset_sha256=${M23_PILOT_SOURCE_DATASET_SHA256:-dc6089e7b9bcf9cb890e01306d286327266c0bf6ba7a7a8e48abb5ca52b3f3e8}

magma_bin=${M23_MAGMA_BIN:-magma}
stage=${M23_BELYI_STAGE:-numerical}
powser=${M23_BELYI_POWSER:-arnoldi}
prec=${M23_BELYI_PREC:-145}
prec_newton=${M23_BELYI_PREC_NEWTON:-500}
degree_bound=${M23_BELYI_DEGREE_BOUND:-28}
class_id=${M23_BELYI_CLASS_ID:-1}
wall_seconds=${M23_BELYI_WALL_SECONDS:-21600}
kill_after_seconds=${M23_BELYI_KILL_AFTER_SECONDS:-30}
version_seconds=${M23_BELYI_VERSION_SECONDS:-10}
memory_mib=${M23_BELYI_MEMORY_MIB:-0}

case "$stage" in numerical|exact) ;; *) echo "invalid M23_BELYI_STAGE" >&2; exit 2;; esac
case "$powser" in arnoldi|carnoldi) ;; *) echo "invalid M23_BELYI_POWSER" >&2; exit 2;; esac
for value in "$prec" "$prec_newton" "$degree_bound" "$class_id" "$class_min" \
             "$class_max" "$wall_seconds" \
             "$kill_after_seconds" "$version_seconds" "$memory_mib"; do
  [[ "$value" =~ ^[0-9]+$ ]] || {
    echo "numeric pilot options must be nonnegative integers" >&2
    exit 2
  }
done
(( prec >= 1 && prec_newton >= prec && degree_bound >= 1 &&
   class_min >= 1 && class_max >= class_min &&
   class_id >= class_min && class_id <= class_max && wall_seconds >= 1 &&
   kill_after_seconds >= 1 && version_seconds >= 1 )) || {
  echo "invalid precision, degree bound, class ID, or time limit" >&2
  exit 2
}

git -C "$belyi_checkout" rev-parse --git-dir >/dev/null 2>&1 || {
  echo "Belyi checkout is not a Git repository" >&2
  exit 2
}
command -v "$magma_bin" >/dev/null 2>&1 || {
  echo "Magma executable not found: $magma_bin" >&2
  exit 2
}
command -v timeout >/dev/null 2>&1 || { echo "GNU timeout is required" >&2; exit 2; }
command -v sha256sum >/dev/null 2>&1 || { echo "sha256sum is required" >&2; exit 2; }
[[ ! -e "$output_dir" ]] || {
  echo "output directory must not already exist" >&2
  exit 2
}
if [[ "$stage" == exact ]]; then
  command -v python3 >/dev/null 2>&1 || { echo "Python 3 is required for exact intake" >&2; exit 2; }
  command -v gap >/dev/null 2>&1 || { echo "GAP is required for exact intake" >&2; exit 2; }
fi

magma_version_output=$(timeout --signal=TERM --kill-after=2s "$version_seconds" \
  "$magma_bin" --version </dev/null 2>&1)
version_code=$?
if [[ $version_code -ne 0 ]]; then
  echo "bounded Magma version preflight failed with exit code $version_code" >&2
  exit 2
fi
magma_version=${magma_version_output%%$'\n'*}
[[ -n "$magma_version" ]] || magma_version=unknown

actual_revision=$(git -C "$belyi_checkout" rev-parse HEAD) || exit 2
if [[ "$actual_revision" != "$pinned_belyi_revision" &&
      ${M23_ALLOW_UNPINNED_BELYI:-0} != 1 ]]; then
  echo "Belyi revision mismatch: expected $pinned_belyi_revision, got $actual_revision" >&2
  exit 2
fi
dirty=$(git -C "$belyi_checkout" status --porcelain) || exit 2
if [[ -n "$dirty" && ${M23_ALLOW_DIRTY_BELYI:-0} != 1 ]]; then
  echo "Belyi checkout is dirty; set M23_ALLOW_DIRTY_BELYI=1 only for diagnostics" >&2
  exit 2
fi
submodule_status=$(git -C "$belyi_checkout" submodule status --recursive) || exit 2
if grep -Eq '^[-+U]' <<<"$submodule_status" &&
   [[ ${M23_ALLOW_UNPINNED_SUBMODULES:-0} != 1 ]]; then
  echo "Belyi submodules are uninitialized or differ from recorded commits" >&2
  exit 2
fi
actual_input_sha256=$(sha256sum "$input_file" | awk '{print $1}')
[[ "$actual_input_sha256" == "$pinned_input_sha256" ]] || {
  echo "project Magma input hash mismatch" >&2
  exit 2
}

carnoldi_sha256=not_used
if [[ "$powser" == carnoldi ]]; then
  [[ -n ${POWSER_ARNOLDI_BIN:-} && -x ${POWSER_ARNOLDI_BIN:-} ]] || {
    echo "carnoldi mode requires executable POWSER_ARNOLDI_BIN" >&2
    exit 2
  }
  carnoldi_sha256=$(sha256sum "$POWSER_ARNOLDI_BIN" | awk '{print $1}')
fi

project_dirty=$(git -C "$project_root" status --porcelain) || exit 2
mkdir "$output_dir" || exit 2
transcript="$output_dir/transcript.log"
config="$output_dir/config.tsv"
status="$output_dir/status.tsv"
candidate="$output_dir/candidate.json"
verification="$output_dir/verification.json"
extraction_log="$output_dir/extraction.log"
verification_log="$output_dir/verification.log"
driver="$output_dir/driver.m"
submodules_file="$output_dir/belyi-submodules.txt"

awk '1' "$input_file" "$pilot_file" >"$driver" || exit 2
printf '%s\n' "$submodule_status" >"$submodules_file"

{
  printf 'key\tvalue\n'
  printf 'project_revision\t%s\n' "$(git -C "$project_root" rev-parse HEAD)"
  printf 'project_dirty\t%s\n' "$([[ -n "$project_dirty" ]] && echo true || echo false)"
  printf 'input_sha256\t%s\n' "$actual_input_sha256"
  printf 'pilot_sha256\t%s\n' "$(sha256sum "$pilot_file" | awk '{print $1}')"
  printf 'runner_sha256\t%s\n' "$(sha256sum "$script_dir/run-class1-pilot.sh" | awk '{print $1}')"
  printf 'entrypoint_sha256\t%s\n' "$(sha256sum "$entrypoint_file" | awk '{print $1}')"
  printf 'extractor_sha256\t%s\n' "$(sha256sum "$extractor" | awk '{print $1}')"
  printf 'verifier_sha256\t%s\n' "$(sha256sum "$verifier" | awk '{print $1}')"
  printf 'schema_sha256\t%s\n' "$(sha256sum "$schema" | awk '{print $1}')"
  printf 'driver_sha256\t%s\n' "$(sha256sum "$driver" | awk '{print $1}')"
  printf 'belyi_revision\t%s\n' "$actual_revision"
  printf 'belyi_dirty\t%s\n' "$([[ -n "$dirty" ]] && echo true || echo false)"
  printf 'belyi_submodules_sha256\t%s\n' "$(sha256sum "$submodules_file" | awk '{print $1}')"
  printf 'magma_executable\t%s\n' "$(command -v "$magma_bin")"
  printf 'magma_version\t%s\n' "$magma_version"
  printf 'python_executable\t%s\n' "$(command -v python3 || echo not_required)"
  printf 'gap_executable\t%s\n' "$(command -v gap || echo not_required)"
  printf 'stage\t%s\n' "$stage"
  printf 'powser\t%s\n' "$powser"
  printf 'carnoldi_sha256\t%s\n' "$carnoldi_sha256"
  printf 'prec\t%s\n' "$prec"
  printf 'prec_newton\t%s\n' "$prec_newton"
  printf 'degree_bound\t%s\n' "$degree_bound"
  printf 'class_id\t%s\n' "$class_id"
  printf 'class_min\t%s\n' "$class_min"
  printf 'class_max\t%s\n' "$class_max"
  printf 'problem_id\t%s\n' "$candidate_problem_id"
  printf 'wall_seconds\t%s\n' "$wall_seconds"
  printf 'kill_after_seconds\t%s\n' "$kill_after_seconds"
  printf 'memory_mib\t%s\n' "$memory_mib"
} >"$config"

export M23_BELYI_STAGE="$stage"
export M23_BELYI_POWSER="$powser"
export M23_BELYI_PREC="$prec"
export M23_BELYI_PREC_NEWTON="$prec_newton"
export M23_BELYI_DEGREE_BOUND="$degree_bound"
export M23_BELYI_CLASS_ID="$class_id"

start_epoch=$(date +%s)
if (( memory_mib > 0 )); then
  (
    ulimit -v $((memory_mib * 1024))
    cd "$belyi_checkout" || exit 2
    exec timeout --signal=TERM --kill-after="${kill_after_seconds}s" "$wall_seconds" \
      "$magma_bin" -b "$driver" </dev/null
  ) >"$transcript" 2>&1
  magma_exit_code=$?
else
  (
    cd "$belyi_checkout" || exit 2
    exec timeout --signal=TERM --kill-after="${kill_after_seconds}s" "$wall_seconds" \
      "$magma_bin" -b "$driver" </dev/null
  ) >"$transcript" 2>&1
  magma_exit_code=$?
fi
elapsed_seconds=$(($(date +%s) - start_epoch))

outcome=failed
runner_exit_code=$magma_exit_code
extraction_exit_code=not_run
verification_exit_code=not_run
if [[ $magma_exit_code -eq 124 ]]; then
  outcome=timeout
elif [[ $magma_exit_code -eq 137 ]]; then
  outcome=timeout_killed
elif [[ $magma_exit_code -eq 0 && "$stage" == numerical ]] &&
     grep -Fx 'M23_NUMERICAL_SUCCESS=true' "$transcript" >/dev/null &&
     grep -Fx 'M23_PILOT_COMPLETE=true' "$transcript" >/dev/null; then
  outcome=numerical_stage_completed
  runner_exit_code=0
elif [[ $magma_exit_code -eq 0 && "$stage" == exact ]] &&
     grep -Fx 'M23_EXACT_SANITY=true' "$transcript" >/dev/null &&
     grep -Fx 'M23_PILOT_COMPLETE=true' "$transcript" >/dev/null; then
  configuration_json=$(printf '{"stage":"%s","powser":"%s","prec":%s,"prec_newton":%s,"degree_bound":%s,"class_id":%s}' \
    "$stage" "$powser" "$prec" "$prec_newton" "$degree_bound" "$class_id")
  source_description=$(printf "$candidate_source_description" "$class_id")
  candidate_tmp="$output_dir/candidate.json.tmp"
  verification_tmp="$output_dir/verification.json.tmp"
  python3 "$extractor" "$transcript" "$candidate_tmp" \
    --package-revision "$actual_revision" --magma-version "$magma_version" \
    --configuration-json "$configuration_json" \
    --problem-id "$candidate_problem_id" \
    --expected-partitions-json "$candidate_partitions_json" \
    --source-description "$source_description" \
    --source-class-id "$class_id" \
    --source-dataset-sha256 "$candidate_source_dataset_sha256" \
    >"$extraction_log" 2>&1
  extraction_exit_code=$?
  if [[ $extraction_exit_code -eq 0 ]]; then
    mv "$candidate_tmp" "$candidate"
    python3 "$verifier" "$candidate" >"$verification_tmp" 2>"$verification_log"
    verification_exit_code=$?
    if [[ $verification_exit_code -eq 0 ]]; then
      mv "$verification_tmp" "$verification"
      outcome=success_exact_verified_ramification
      runner_exit_code=0
    else
      if [[ -s "$verification_tmp" ]]; then
        mv "$verification_tmp" "$output_dir/verification.rejected.json"
      else
        rm -f "$verification_tmp"
      fi
      outcome=exact_output_rejected_locally
      runner_exit_code=1
    fi
  else
    if [[ -s "$candidate_tmp" ]]; then
      mv "$candidate_tmp" "$output_dir/candidate.rejected.json"
    else
      rm -f "$candidate_tmp"
    fi
    outcome=exact_output_rejected_locally
    runner_exit_code=1
  fi
fi
if [[ "$outcome" == failed && $runner_exit_code -eq 0 ]]; then
  runner_exit_code=1
fi

{
  printf 'key\tvalue\n'
  printf 'outcome\t%s\n' "$outcome"
  printf 'magma_exit_code\t%s\n' "$magma_exit_code"
  printf 'extraction_exit_code\t%s\n' "$extraction_exit_code"
  printf 'verification_exit_code\t%s\n' "$verification_exit_code"
  printf 'runner_exit_code\t%s\n' "$runner_exit_code"
  printf 'elapsed_seconds\t%s\n' "$elapsed_seconds"
  printf 'transcript_sha256\t%s\n' "$(sha256sum "$transcript" | awk '{print $1}')"
  if [[ -s "$candidate" ]]; then
    printf 'candidate_sha256\t%s\n' "$(sha256sum "$candidate" | awk '{print $1}')"
  fi
  if [[ -s "$verification" ]]; then
    printf 'verification_sha256\t%s\n' "$(sha256sum "$verification" | awk '{print $1}')"
  fi
} >"$status"

printf '%s\n' "$outcome"
exit "$runner_exit_code"
