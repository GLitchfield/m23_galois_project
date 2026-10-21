#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 5 || $# -gt 6 ]]; then
  echo "usage: $0 CHECKPOINT BLOCK TWIST WEIGHT LIMIT [REPEATS]" >&2
  exit 2
fi

checkpoint=$(realpath "$1")
repeats=${6:-3}
binary=$(mktemp)
trap 'rm -f "$binary"' EXIT

${CXX:-g++} -std=c++20 -O3 -DNDEBUG -Wall -Wextra -Werror \
  -Isrc/native src/native/m23_kernel.cpp \
  tests/native/benchmark_m23_bounded_walk.cpp -o "$binary"
/usr/bin/time -f $'wall_seconds\t%e\nmax_rss_kib\t%M' \
  "$binary" "$checkpoint" "$2" "$3" "$4" "$5" "$repeats"
