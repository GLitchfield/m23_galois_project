#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 CHECKPOINT.bin" >&2
  exit 2
fi
checkpoint=$1
[[ -s "$checkpoint" ]] || { echo "missing coordinate checkpoint" >&2; exit 2; }
binary=$(mktemp)
trap 'rm -f "$binary"' EXIT
${CXX:-g++} -std=c++20 -O2 -Wall -Wextra -Werror \
  -Isrc/native src/native/m23_kernel.cpp \
  tests/native/check_m23_coordinate_checkpoint.cpp -o "$binary"
"$binary" "$checkpoint"
