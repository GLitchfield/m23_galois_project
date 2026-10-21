#!/usr/bin/env bash
set -euo pipefail

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

pair_checkpoint=${M23_5A_PAIR_CHECKPOINT:-runs/5a-pair-orbits-v2.g}
if [[ ! -s "$pair_checkpoint" ]]; then
  pair_checkpoint="$work/5a-pair-orbits-v2.g"
  ./scripts/generate-homogeneous-pair-orbits.sh 5 "$pair_checkpoint"
fi
pair_checkpoint=$(realpath "$pair_checkpoint")
pair_sha256=$(sha256sum "$pair_checkpoint" | cut -d' ' -f1)

coordinate_checkpoint=${M23_5A_COORDINATE_CHECKPOINT:-}
if [[ -z "$coordinate_checkpoint" ]]; then
  coordinate_checkpoint="$work/5a-coordinate-tables.bin"
  ./scripts/generate-native-coordinate-checkpoint.sh \
    "$pair_checkpoint" "$coordinate_checkpoint" \
    "$work/coordinate-export-progress.tsv"
else
  coordinate_checkpoint=$(realpath "$coordinate_checkpoint")
fi

M23_PAIR_CHECKPOINT="$pair_checkpoint" M23_PAIR_SHA256="$pair_sha256" \
M23_SOURCE_BLOCK=71532995 M23_SOURCE_TWIST=1 M23_WALK_LIMIT=30400 \
M23_OUTPUT="$work/native-5a-bounded-walk.tsv" \
  gap --quitonbreak -q scripts/gap/generate_native_bounded_walk_fixture.g
cmp data/reference/native_5a_bounded_walk_30400_fixture.tsv \
  "$work/native-5a-bounded-walk.tsv"

${CXX:-g++} -std=c++20 -O2 -Wall -Wextra -Werror \
  -Isrc/native src/native/m23_kernel.cpp \
  tests/native/test_m23_bounded_walk.cpp -o "$work/check-native-5a-walk"
"$work/check-native-5a-walk" \
  data/reference/native_5a_bounded_walk_30400_fixture.tsv \
  "$coordinate_checkpoint"
