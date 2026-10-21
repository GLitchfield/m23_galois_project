#!/usr/bin/env bash
set -euo pipefail

binary=$(mktemp)
database=$(mktemp)
rm -f "$database"
trap 'rm -f "$binary" "$database" "$database-shm" "$database-wal"' EXIT

${CXX:-g++} -std=c++20 -O2 -Wall -Wextra -Werror -Isrc/native \
  src/native/m23_native_sqlite.cpp src/native/m23_native_replay.cpp \
  tests/native/test_m23_native_replay.cpp -lsqlite3 -o "$binary"
"$binary" "$database"
