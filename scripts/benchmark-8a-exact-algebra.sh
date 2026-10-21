#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
prime="${1:-13}"
presentation="${2:-full}"
wall_seconds="${3:-60}"
threads="${4:-8}"
run_dir="${5:-$repo_root/runs/8a-exact-algebra-p${prime}-${presentation}-${wall_seconds}s}"

if [[ ! "$prime" =~ ^[0-9]+$ ]] ||
   [[ ! "$wall_seconds" =~ ^[1-9][0-9]*$ ]] ||
   [[ ! "$threads" =~ ^[1-9][0-9]*$ ]]; then
    echo "usage: $0 [prime] [full|reduced] [wall_seconds] [threads] [run_dir]" >&2
    exit 2
fi
if [[ "$presentation" != "full" && "$presentation" != "reduced" ]]; then
    echo "presentation must be full or reduced" >&2
    exit 2
fi

mkdir -p "$run_dir"
cd "$repo_root"

input_file="$run_dir/system.ms"
export_log="$run_dir/export.log"
msolve_output="$run_dir/msolve.out"
msolve_log="$run_dir/msolve.log"
msolve_time="$run_dir/msolve.time"
singular_log="$run_dir/singular.log"
singular_time="$run_dir/singular.time"

./scripts/run-8a-sage.sh --python \
    scripts/export_8a_belyi_msolve.sage \
    --prime "$prime" \
    --presentation "$presentation" \
    --output "$input_file" \
    >"$export_log"

{
    printf 'key\tvalue\n'
    printf 'git_revision\t%s\n' "$(git rev-parse HEAD)"
    printf 'prime\t%s\n' "$prime"
    printf 'presentation\t%s\n' "$presentation"
    printf 'wall_seconds\t%s\n' "$wall_seconds"
    printf 'threads\t%s\n' "$threads"
    printf 'sage_version\t%s\n' "$(./scripts/run-8a-sage.sh --version)"
    printf 'singular_version\t%s\n' \
        "$(build/sage-8a/bin/Singular --version | sed -n '1s/^Singular for .* version //p')"
    printf 'msolve_version\t%s\n' "$(./scripts/run-msolve.sh -V)"
    printf 'system_sha256\t%s\n' "$(sha256sum "$input_file" | cut -d' ' -f1)"
    printf 'system_bytes\t%s\n' "$(wc -c <"$input_file")"
    printf 'export_summary\t%s\n' "$(tr '\n' ' ' <"$export_log")"
} >"$run_dir/config.tsv"

set +e
/usr/bin/time -v -o "$msolve_time" \
    timeout --signal=TERM --kill-after=10s "${wall_seconds}s" \
    ./scripts/run-msolve.sh \
        -f "$input_file" \
        -o "$msolve_output" \
        -t "$threads" \
        -v 2 \
        --random-seed 1 \
    >"$msolve_log" 2>&1
msolve_status=$?

/usr/bin/time -v -o "$singular_time" \
    timeout --signal=TERM --kill-after=10s "${wall_seconds}s" \
    ./scripts/run-8a-sage.sh --python \
        scripts/benchmark_8a_singular.sage \
        --prime "$prime" \
        --presentation "$presentation" \
    >"$singular_log" 2>&1
singular_status=$?
set -e

{
    printf 'engine\texit_status\tcompleted\tmax_rss_kib\n'
    printf 'msolve\t%s\t%s\t%s\n' \
        "$msolve_status" \
        "$([[ "$msolve_status" -eq 0 ]] && echo yes || echo no)" \
        "$(sed -n 's/^[[:space:]]*Maximum resident set size (kbytes): //p' "$msolve_time")"
    printf 'singular\t%s\t%s\t%s\n' \
        "$singular_status" \
        "$([[ "$singular_status" -eq 0 ]] && echo yes || echo no)" \
        "$(sed -n 's/^[[:space:]]*Maximum resident set size (kbytes): //p' "$singular_time")"
} >"$run_dir/summary.tsv"

cat "$run_dir/config.tsv"
cat "$run_dir/summary.tsv"
