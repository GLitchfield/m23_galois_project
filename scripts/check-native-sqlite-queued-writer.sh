#!/usr/bin/env bash
set -euo pipefail

binary=$(mktemp)
error=$(mktemp)
trap 'rm -f "$binary" "$error"' EXIT

${CXX:-g++} -std=c++20 -O2 -Wall -Wextra -Werror -pthread -Isrc/native \
  src/native/m23_kernel.cpp src/native/m23_native_sqlite.cpp \
  src/native/m23_native_sqlite_queued_worker.cpp -lsqlite3 -o "$binary"

if "$binary" 2>"$error"; then
  echo "queued native worker accepted missing arguments" >&2
  exit 1
fi
grep -q '^usage: m23_native_sqlite_queued_worker ' "$error"
echo "native queued SQLite writer compiled and validated"
