#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 || $# -gt 4 ]]; then
  echo "usage: $0 ARCHIVE RUN_DIR [WALL_SECONDS] [THREADS]" >&2
  exit 2
fi

archive=$1
run_dir=$2
wall_seconds=${3:-120}
threads=${4:-4}
repo_root=$(cd "$(dirname "$0")/.." && pwd)

if [[ ! "$wall_seconds" =~ ^[1-9][0-9]*$ ]] ||
   [[ ! "$threads" =~ ^[1-9][0-9]*$ ]]; then
  echo "wall seconds and threads must be positive integers" >&2
  exit 2
fi
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
  scripts/export_koenig_second_prime_msolve.sage \
  "$archive" \
  --prime 11 \
  --alpha 0 \
  --beta 6 \
  --lambda 1 \
  --presentation scaled \
  --output "$input" >"$export_log"

set +e
/usr/bin/time -v -o "$time_log" \
  timeout --signal=TERM --kill-after=10s "${wall_seconds}s" \
  ./scripts/run-msolve.sh \
    -f "$input" \
    -o "$output" \
    -t "$threads" \
    --random-seed 1 \
    -v 2 >"$log" 2>&1
status=$?
set -e

case $status in
  0) outcome=completed ;;
  124) outcome=timeout ;;
  137) outcome=timeout_killed ;;
  *) outcome=failed ;;
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
read -r maximum_rows maximum_columns < <(
  awk '
    $1 ~ /^[0-9]+$/ && $5 == "x" {
      if ($4 > rows) rows=$4
      if ($6 > columns) columns=$6
    }
    END { print rows+0, columns+0 }
  ' "$log"
)

{
  printf '# schema\tm23-koenig-second-prime-msolve-benchmark-v1\n'
  printf '# code_revision\t%s\n' "$(git rev-parse HEAD)"
  printf '# archive_sha256\t%s\n' "$(sha256sum "$archive" | cut -d' ' -f1)"
  printf 'wall_limit_seconds\t%s\n' "$wall_seconds"
  printf 'threads\t%s\n' "$threads"
  printf 'msolve_version\t%s\n' "$(./scripts/run-msolve.sh -V)"
  printf 'input_sha256\t%s\n' "$(sha256sum "$input" | cut -d' ' -f1)"
  printf 'exit_status\t%s\n' "$status"
  printf 'outcome\t%s\n' "$outcome"
  printf 'maximum_rss_kib\t%s\n' "$maximum_rss"
  printf 'highest_f4_degree\t%s\n' "$highest_degree"
  printf 'maximum_f4_rows\t%s\n' "$maximum_rows"
  printf 'maximum_f4_columns\t%s\n' "$maximum_columns"
} >"$summary"

cat "$summary"
