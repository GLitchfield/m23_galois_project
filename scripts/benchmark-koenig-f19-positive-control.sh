#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 4 ]]; then
  echo "usage: $0 RUN_DIR [WALL_SECONDS] [THREADS] [VMEM_LIMIT_KIB]" >&2
  exit 2
fi

run_dir=$1
wall_seconds=${2:-7200}
threads=${3:-4}
vmem_limit_kib=${4:-8388608}
max_pairs=2048
repo_root=$(cd "$(dirname "$0")/.." && pwd)

for value in "$wall_seconds" "$threads" "$vmem_limit_kib"; do
  if [[ ! "$value" =~ ^[1-9][0-9]*$ ]]; then
    echo "limits and thread count must be positive integers" >&2
    exit 2
  fi
done
if [[ -e "$run_dir" ]]; then
  echo "run directory already exists: $run_dir" >&2
  exit 2
fi
mkdir -p "$run_dir"

input=$run_dir/system.in
output=$run_dir/msolve.out
log=$run_dir/msolve.log
time_log=$run_dir/msolve.time
export_log=$run_dir/export.log
summary=$run_dir/summary.tsv

cd "$repo_root"
./scripts/run-8a-sage.sh --python \
  scripts/export_koenig_f19_positive_control_msolve.sage \
  --output "$input" >"$export_log"
: >"$output"

set +e
(
  ulimit -v "$vmem_limit_kib"
  /usr/bin/time -v -o "$time_log" \
    timeout --signal=TERM --kill-after=10s "${wall_seconds}s" \
    ./scripts/run-msolve.sh \
      -f "$input" \
      -o "$output" \
      -t "$threads" \
      -m "$max_pairs" \
      --random-seed 1 \
      -v 2 >"$log" 2>&1
)
status=$?
set -e

case $status in
  0) outcome=completed ;;
  124) outcome=timeout ;;
  137) outcome=timeout_killed ;;
  *)
    if rg -q 'Cannot allocate memory|bad_alloc|out of memory' "$log"; then
      outcome=memory_limit
    else
      outcome=failed
    fi
    ;;
esac

maximum_rss=$(
  sed -n \
    's/^[[:space:]]*Maximum resident set size (kbytes): //p' \
    "$time_log"
)
highest_degree=$(
  awk '$1 ~ /^[0-9]+$/ { if ($1 > maximum) maximum=$1 } END { print maximum+0 }' \
    "$log"
)
read -r maximum_rows maximum_columns maximum_pair_frontier < <(
  awk '
    $1 ~ /^[0-9]+$/ {
      if ($4 > rows) rows=$4
      if ($6 > columns) columns=$6
      if ($3 > pairs) pairs=$3
    }
    END { print rows+0, columns+0, pairs+0 }
  ' "$log"
)

{
  printf '# schema\tm23-koenig-f19-positive-control-benchmark-v1\n'
  printf '# code_revision\t%s\n' "$(git rev-parse HEAD)"
  printf 'wall_limit_seconds\t%s\n' "$wall_seconds"
  printf 'threads\t%s\n' "$threads"
  printf 'vmem_limit_kib\t%s\n' "$vmem_limit_kib"
  printf 'max_pairs_per_matrix\t%s\n' "$max_pairs"
  printf 'msolve_version\t%s\n' "$(./scripts/run-msolve.sh -V)"
  printf 'input_sha256\t%s\n' "$(sha256sum "$input" | cut -d' ' -f1)"
  printf 'exit_status\t%s\n' "$status"
  printf 'outcome\t%s\n' "$outcome"
  printf 'output_bytes\t%s\n' "$(wc -c <"$output")"
  printf 'maximum_rss_kib\t%s\n' "$maximum_rss"
  printf 'highest_f4_degree\t%s\n' "$highest_degree"
  printf 'maximum_f4_rows\t%s\n' "$maximum_rows"
  printf 'maximum_f4_columns\t%s\n' "$maximum_columns"
  printf 'maximum_pair_frontier\t%s\n' "$maximum_pair_frontier"
} >"$summary"

cat "$summary"
