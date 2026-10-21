#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 10 ]]; then
  echo "usage: $0 COORDINATES MASKS LEDGER RUN_DIR WORKERS BLOCK_TARGET START PROOF WALK LEASE" >&2
  exit 2
fi

coordinates=$(realpath "$1")
masks=$(realpath "$2")
ledger=$(realpath "$3")
run_dir=$4
workers=$5
block_target=$6
start=$7
proof=$8
walk=$9
shift 9
lease=$1
crash_shard=${M23_NATIVE_CRASH_SHARD:-0}

for value in "$workers" "$block_target" "$start" "$proof" "$walk" "$lease"; do
  [[ "$value" =~ ^[1-9][0-9]*$ ]] || {
    echo "invalid positive integer: $value" >&2
    exit 2
  }
done
[[ "$crash_shard" =~ ^[0-9]+$ ]] && (( crash_shard <= workers )) || {
  echo "invalid native crash shard: $crash_shard" >&2
  exit 2
}
(( walk >= proof )) || {
  echo "walk limit must be at least the proof limit" >&2
  exit 2
}
mkdir -p "$run_dir"
binary=$(mktemp)
trap 'rm -f "$binary"' EXIT

${CXX:-g++} -std=c++20 -O3 -DNDEBUG -Wall -Wextra -Werror \
  -Isrc/native src/native/m23_kernel.cpp src/native/m23_native_sqlite.cpp \
  src/native/m23_native_sqlite_worker.cpp -lsqlite3 -o "$binary"

pids=()
for ((shard = 1; shard <= workers; shard++)); do
  if (( shard == crash_shard )); then
    M23_NATIVE_EXIT_AFTER_CERTIFICATE=1 \
      "$binary" "$coordinates" "$masks" "$ledger" \
      "native-$shard-of-$workers" "$shard" "$workers" "$block_target" \
      "$start" "$proof" "$walk" "$lease" \
      >"$run_dir/worker-$shard.log" 2>&1 &
  else
    "$binary" "$coordinates" "$masks" "$ledger" \
      "native-$shard-of-$workers" "$shard" "$workers" "$block_target" \
      "$start" "$proof" "$walk" "$lease" \
      >"$run_dir/worker-$shard.log" 2>&1 &
  fi
  pids+=("$!")
done

status=0
for pid in "${pids[@]}"; do
  if ! wait "$pid"; then
    status=1
  fi
done
if (( status != 0 )); then
  echo "one or more native SQLite workers failed (crash_shard=$crash_shard)" >&2
  exit 1
fi

echo "completed $workers native SQLite workers at target $block_target"
