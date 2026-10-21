#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 && $# -ne 4 ]]; then
  echo "usage: $0 COORDINATES LEDGER [FIRST_CERTIFICATE LAST_CERTIFICATE]" >&2
  exit 2
fi

coordinates=$(realpath "$1")
ledger=$(realpath "$2")
binary=$(mktemp)
trap 'rm -f "$binary"' EXIT

${CXX:-g++} -std=c++20 -O3 -DNDEBUG -Wall -Wextra -Werror \
  -Isrc/native src/native/m23_kernel.cpp src/native/m23_native_replay.cpp \
  src/native/m23_native_sqlite_replay.cpp -lsqlite3 -o "$binary"
if [[ $# -eq 2 ]]; then
  "$binary" "$coordinates" "$ledger"
else
  "$binary" "$coordinates" "$ledger" "$3" "$4"
fi
