#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 LEDGER.sqlite3 TRANSCRIPT.tsv" >&2
  exit 2
fi

binary=$(mktemp)
trap 'rm -f "$binary"' EXIT
${CXX:-g++} -std=c++20 -O3 -DNDEBUG -Wall -Wextra -Werror \
  src/native/m23_sqlite_lookup_benchmark.cpp -lsqlite3 -o "$binary"
"$binary" "$1" "$2"
