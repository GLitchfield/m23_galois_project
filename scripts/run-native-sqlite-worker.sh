#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 11 ]]; then
  echo "usage: $0 COORDINATES MASKS LEDGER WORKER SHARD_INDEX SHARD_COUNT BLOCK_TARGET START PROOF WALK LEASE" >&2
  exit 2
fi

coordinates=$(realpath "$1")
masks=$(realpath "$2")
binary=$(mktemp)
trap 'rm -f "$binary"' EXIT

${CXX:-g++} -std=c++20 -O3 -DNDEBUG -Wall -Wextra -Werror \
  -Isrc/native src/native/m23_kernel.cpp src/native/m23_native_sqlite.cpp \
  src/native/m23_native_sqlite_worker.cpp -lsqlite3 -o "$binary"
"$binary" "$coordinates" "$masks" "$3" "$4" "$5" "$6" "$7" \
  "$8" "$9" "${10}" "${11}"
