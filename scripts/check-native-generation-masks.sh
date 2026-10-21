#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 COORDINATES.bin MASKS.bin" >&2
  exit 2
fi
coordinates=$1
masks=$2
[[ -s "$coordinates" ]] || { echo "missing coordinate checkpoint" >&2; exit 2; }
[[ -s "$masks" ]] || { echo "missing generation-mask checkpoint" >&2; exit 2; }
binary=$(mktemp)
trap 'rm -f "$binary"' EXIT
${CXX:-g++} -std=c++20 -O2 -Wall -Wextra -Werror \
  -Isrc/native src/native/m23_kernel.cpp \
  tests/native/check_m23_generation_masks.cpp -o "$binary"
"$binary" "$coordinates" "$masks"
