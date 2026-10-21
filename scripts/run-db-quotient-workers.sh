#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 9 ]]; then
  echo "usage: $0 PAIR_CHECKPOINT FIRST_ORDINAL LAST_ORDINAL START_ORDINAL PROOF_LIMIT WALK_LIMIT RUN_DIR WORKERS GLOBAL_BLOCK_TARGET" >&2
  exit 2
fi

pair_checkpoint=$1
first_ordinal=$2
last_ordinal=$3
start_ordinal=$4
proof_limit=$5
walk_limit=$6
run_dir=$7
workers=$8
global_block_target=$9
[[ -s "$pair_checkpoint" ]] || { echo "missing pair checkpoint" >&2; exit 2; }
for value in "$first_ordinal" "$last_ordinal" "$start_ordinal" "$proof_limit" "$walk_limit" "$workers" "$global_block_target"; do
  [[ "$value" =~ ^[1-9][0-9]*$ ]] || { echo "invalid positive integer: $value" >&2; exit 2; }
done
(( walk_limit >= proof_limit )) || { echo "walk limit must be at least proof limit" >&2; exit 2; }
mkdir -p "$run_dir"

min_available_mib=${M23_MIN_AVAILABLE_MIB:-8192}
cache_reset_interval=${M23_CACHE_RESET_INTERVAL:-1000}
worker_offset=${M23_WORKER_OFFSET:-0}
for value in "$min_available_mib" "$cache_reset_interval" "$worker_offset"; do
  [[ "$value" =~ ^[0-9]+$ ]] || {
    echo "invalid nonnegative resource limit: $value" >&2
    exit 2
  }
done
available_mib=$(awk '/^MemAvailable:/ { print int($2 / 1024) }' /proc/meminfo)
if (( available_mib < min_available_mib )); then
  echo "refusing to start quotient workers: ${available_mib} MiB available, ${min_available_mib} MiB required" >&2
  exit 75
fi

# Prepare WAL mode and any schema migrations before concurrent workers open
# the ledger.  Doing this in each worker can require an exclusive SQLite lock
# after another worker has already begun a long certificate transaction.
python3 scripts/m23_quotient_ledger.py --initialize-only \
  "$run_dir/ledger.sqlite3"

pids=()
for ((worker = 1; worker <= workers; worker++)); do
  worker_id=$((worker_offset + worker))
  (
    export M23_WORKER_ID="worker-$worker_id"
    export M23_LEASE_SECONDS=${M23_LEASE_SECONDS:-300}
    # Full ledger statistics include an exact pending-frontier join and become
    # expensive on multi-million-row ledgers.  Ten-second-scale dashboard
    # updates are sufficient; mathematical events and commits remain per item.
    export M23_PROGRESS_INTERVAL=${M23_PROGRESS_INTERVAL:-100}
    # Direct coordinate refinements and their relative maps are reusable but
    # not proof state.  Bound their lifetime so a long wave cannot consume all
    # RAM merely because its GAP workers remain alive.
    export M23_CACHE_RESET_INTERVAL="$cache_reset_interval"
    export M23_GLOBAL_BLOCK_TARGET="$global_block_target"
    if [[ ${M23_DETERMINISTIC_SHARDS:-0} == dynamic ]]; then
      export M23_SHARD_INDEX=0
      export M23_SHARD_COUNT=${M23_VIRTUAL_SHARDS:-$workers}
    elif [[ ${M23_DETERMINISTIC_SHARDS:-0} == 1 ]]; then
      export M23_SHARD_INDEX="$worker_id"
      export M23_SHARD_COUNT=${M23_VIRTUAL_SHARDS:-$workers}
    fi
    ./scripts/scan-direct-pair-quotient-db.sh "$pair_checkpoint" \
      "$first_ordinal" "$last_ordinal" "$proof_limit" "$run_dir" \
      frontier "$start_ordinal" "$global_block_target" "$walk_limit"
  ) >"$run_dir/worker-$worker_id.log" 2>&1 &
  pids+=("$!")
done

status=0
for pid in "${pids[@]}"; do
  if ! wait "$pid"; then
    status=1
  fi
done
if (( status != 0 )); then
  echo "one or more quotient workers failed; inspect $run_dir/worker-*.log" >&2
  exit "$status"
fi

echo "completed $workers workers at global target $global_block_target"
