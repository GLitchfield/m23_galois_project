#!/usr/bin/env bash
set -euo pipefail

if (( $# < 3 || $# > 7 )); then
    echo "usage: $0 FAMILY ARCHIVE OUTPUT [RUN_DIR] [WORKERS] [SHARDS] [TOTAL_MODULI]" >&2
    exit 2
fi

family="$1"
archive="$2"
output="$3"
run_dir="${4:-runs/koenig-f19-global}"
workers="${5:-12}"
shards="${6:-28}"
total_moduli="${7:-224}"
modulus_degree=128

if (( workers < 1 || shards < 1 || total_moduli < 1 )); then
    echo "workers, shards, and total moduli must be positive" >&2
    exit 2
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$repo_root/$run_dir"
per_shard=$(( (total_moduli + shards - 1) / shards ))
pids=()

wait_oldest() {
    local pid="${pids[0]}"
    wait "$pid"
    pids=("${pids[@]:1}")
}

for (( shard = 0; shard < shards; shard++ )); do
    start=$(( shard * per_shard ))
    if (( start >= total_moduli )); then
        break
    fi
    count="$per_shard"
    if (( start + count > total_moduli )); then
        count=$(( total_moduli - start ))
    fi
    shard_name="$(printf 'shard-%03d.tsv' "$shard")"
    log_name="$(printf 'shard-%03d.log' "$shard")"
    "$repo_root/scripts/run-8a-sage.sh" --python \
        "$repo_root/scripts/certify_koenig_f19_global.sage" \
        "$repo_root/$family" "$archive" \
        --modulus-degree "$modulus_degree" \
        --start-index "$start" \
        --count "$count" \
        --output "$repo_root/$run_dir/$shard_name" \
        >"$repo_root/$run_dir/$log_name" 2>&1 &
    pids+=("$!")
    if (( ${#pids[@]} >= workers )); then
        wait_oldest
    fi
done

while (( ${#pids[@]} )); do
    wait_oldest
done

python3 "$repo_root/scripts/assemble_koenig_f19_global_certificate.py" \
    "$repo_root/$run_dir"/shard-*.tsv \
    --output "$repo_root/$output"
