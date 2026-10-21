#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 7 ]]; then
  echo "usage: $0 COORDINATES MASKS START COUNT PROOF WALK OUTPUT" >&2
  echo "   or: $0 COORDINATES MASKS --stratified SAMPLES PROOF WALK OUTPUT" >&2
  exit 2
fi

coordinates=$(realpath "$1")
masks=$(realpath "$2")
binary=$(mktemp)
trap 'rm -f "$binary"' EXIT

${CXX:-g++} -std=c++20 -O3 -DNDEBUG -Wall -Wextra -Werror \
  -Isrc/native src/native/m23_kernel.cpp \
  src/native/m23_native_ledger_batch.cpp -o "$binary"
/usr/bin/time -f $'wall_seconds\t%e\nmax_rss_kib\t%M' \
  "$binary" "$coordinates" "$masks" "$3" "$4" "$5" "$6" "$7"
