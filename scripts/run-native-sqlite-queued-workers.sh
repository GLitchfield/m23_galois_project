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
batch_max=${M23_NATIVE_BATCH_MAX:-16}
batch_wait_us=${M23_NATIVE_BATCH_WAIT_US:-0}

for value in "$workers" "$block_target" "$start" "$proof" "$walk" \
    "$lease" "$batch_max"; do
  [[ "$value" =~ ^[1-9][0-9]*$ ]] || {
    echo "invalid positive integer: $value" >&2
    exit 2
  }
done
[[ "$batch_wait_us" =~ ^[0-9]+$ ]] || {
  echo "invalid nonnegative batch wait: $batch_wait_us" >&2
  exit 2
}
(( walk >= proof )) || {
  echo "walk limit must be at least the proof limit" >&2
  exit 2
}
mkdir -p "$run_dir"
binary=$(mktemp)
trap 'rm -f "$binary"' EXIT

${CXX:-g++} -std=c++20 -O3 -DNDEBUG -Wall -Wextra -Werror -pthread \
  -Isrc/native src/native/m23_kernel.cpp src/native/m23_native_sqlite.cpp \
  src/native/m23_native_sqlite_queued_worker.cpp -lsqlite3 -o "$binary"

"$binary" "$coordinates" "$masks" "$ledger" "$workers" "$block_target" \
  "$start" "$proof" "$walk" "$lease" "$batch_max" "$batch_wait_us" \
  >"$run_dir/worker-queue.log" 2>&1

echo "completed $workers queued native SQLite workers at target $block_target"
