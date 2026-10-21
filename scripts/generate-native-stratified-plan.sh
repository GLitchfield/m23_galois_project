#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 6 ]]; then
  echo "usage: $0 COORDINATES MASKS SAMPLES_PER_SEGMENT PROOF WALK OUTPUT" >&2
  exit 2
fi

coordinates=$(realpath "$1")
masks=$(realpath "$2")
binary=$(mktemp)
trap 'rm -f "$binary"' EXIT

${CXX:-g++} -std=c++20 -O3 -DNDEBUG -Wall -Wextra -Werror \
  -Isrc/native src/native/m23_kernel.cpp \
  src/native/m23_native_ledger_batch.cpp -o "$binary"
M23_NATIVE_PLAN_ONLY=1 "$binary" "$coordinates" "$masks" \
  --stratified "$3" "$4" "$5" "$6"
