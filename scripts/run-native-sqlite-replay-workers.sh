#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 4 ]]; then
  echo "usage: $0 COORDINATES LEDGER RUN_DIR WORKERS" >&2
  exit 2
fi

coordinates=$(realpath "$1")
ledger=$(realpath "$2")
run_dir=$3
workers=$4
[[ "$workers" =~ ^[1-9][0-9]*$ ]] || {
  echo "invalid positive replay worker count: $workers" >&2
  exit 2
}
mkdir -p "$run_dir"
binary=$(mktemp)
trap 'rm -f "$binary"' EXIT

${CXX:-g++} -std=c++20 -O3 -DNDEBUG -Wall -Wextra -Werror \
  -Isrc/native src/native/m23_kernel.cpp src/native/m23_native_replay.cpp \
  src/native/m23_native_sqlite_replay.cpp -lsqlite3 -o "$binary"
mapfile -t ranges < <(python3 scripts/partition_native_replay.py \
  "$ledger" "$workers")
(( ${#ranges[@]} == workers )) || {
  echo "native replay partition returned the wrong number of ranges" >&2
  exit 2
}

pids=()
for range in "${ranges[@]}"; do
  read -r shard first last work <<<"$range"
  echo -e "range\t$shard\t$first\t$last\t$work" \
    >"$run_dir/replay-$shard.log"
  "$binary" "$coordinates" "$ledger" "$first" "$last" \
    >>"$run_dir/replay-$shard.log" 2>&1 &
  pids+=("$!")
done

status=0
for pid in "${pids[@]}"; do
  if ! wait "$pid"; then
    status=1
  fi
done
if (( status != 0 )); then
  echo "one or more native prefix replay workers failed" >&2
  exit 1
fi

echo "completed $workers cost-balanced native replay workers"
