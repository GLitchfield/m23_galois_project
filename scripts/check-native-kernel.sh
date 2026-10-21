#!/usr/bin/env bash
set -euo pipefail

binary=$(mktemp)
coordinate_binary=$(mktemp)
walk_binary=$(mktemp)
fixture=$(mktemp)
coordinate_fixture=$(mktemp)
coordinate_collision_fixture=$(mktemp)
bounded_walk_fixture=$(mktemp)
bounded_walk_2500_fixture=$(mktemp)
coordinate_census=$(mktemp)
coordinate_binary_checkpoint=$(mktemp)
global_coordinate_checkpoint=$(mktemp)
generated_checkpoint=""
trap 'rm -f "$binary" "$coordinate_binary" "$walk_binary" "$fixture" \
  "$coordinate_fixture" "$coordinate_collision_fixture" \
  "$bounded_walk_fixture" "$bounded_walk_2500_fixture" \
  "$coordinate_census" "$coordinate_binary_checkpoint" \
  "$global_coordinate_checkpoint" \
  "$generated_checkpoint"' EXIT
M23_OUTPUT="$fixture" gap --quitonbreak -q \
  scripts/gap/generate_native_kernel_fixture.g
cmp data/reference/native_kernel_fixture.tsv "$fixture"
${CXX:-g++} -std=c++20 -O2 -Wall -Wextra -Werror \
  -Isrc/native src/native/m23_kernel.cpp tests/native/test_m23_kernel.cpp \
  -o "$binary"
"$binary" data/reference/native_kernel_fixture.tsv

pair_checkpoint=${M23_PAIR_CHECKPOINT:-runs/4a-pair-orbits-v2.g}
if [[ ! -f "$pair_checkpoint" ]]; then
  generated_checkpoint=$(mktemp)
  ./scripts/generate-homogeneous-pair-orbits.sh 4 "$generated_checkpoint"
  pair_checkpoint=$generated_checkpoint
fi
pair_sha256=$(sha256sum "$pair_checkpoint" | cut -d' ' -f1)
M23_PAIR_CHECKPOINT="$pair_checkpoint" M23_PAIR_SHA256="$pair_sha256" \
M23_OUTPUT="$coordinate_fixture" gap --quitonbreak -q \
  scripts/gap/generate_native_coordinate_fixture.g
cmp data/reference/native_coordinate_fixture.tsv "$coordinate_fixture"
M23_PAIR_CHECKPOINT="$pair_checkpoint" M23_PAIR_SHA256="$pair_sha256" \
M23_SOURCE_BLOCK=2 M23_SOURCE_TWIST=1 \
M23_OUTPUT="$coordinate_collision_fixture" gap --quitonbreak -q \
  scripts/gap/generate_native_coordinate_fixture.g
cmp data/reference/native_coordinate_collision_fixture.tsv \
  "$coordinate_collision_fixture"
M23_PAIR_CHECKPOINT="$pair_checkpoint" M23_PAIR_SHA256="$pair_sha256" \
M23_OUTPUT="$coordinate_census" gap --quitonbreak -q \
  scripts/gap/generate_native_coordinate_table_census.g
cmp data/reference/native_4a_coordinate_table_census.tsv "$coordinate_census"
M23_PAIR_CHECKPOINT="$pair_checkpoint" M23_PAIR_SHA256="$pair_sha256" \
M23_OUTPUT="$bounded_walk_fixture" gap --quitonbreak -q \
  scripts/gap/generate_native_bounded_walk_fixture.g
cmp data/reference/native_bounded_walk_fixture.tsv "$bounded_walk_fixture"
M23_PAIR_CHECKPOINT="$pair_checkpoint" M23_PAIR_SHA256="$pair_sha256" \
M23_WALK_LIMIT=2500 M23_OUTPUT="$bounded_walk_2500_fixture" \
  gap --quitonbreak -q scripts/gap/generate_native_bounded_walk_fixture.g
cmp data/reference/native_bounded_walk_2500_fixture.tsv \
  "$bounded_walk_2500_fixture"
M23_PAIR_CHECKPOINT="$pair_checkpoint" M23_PAIR_SHA256="$pair_sha256" \
M23_GIT_REVISION="$(git rev-parse HEAD)" \
M23_OUTPUT="$global_coordinate_checkpoint" gap --quitonbreak -q \
  scripts/gap/export_native_coordinate_checkpoint.g
${CXX:-g++} -std=c++20 -O2 -Wall -Wextra -Werror \
  -Isrc/native src/native/m23_kernel.cpp \
  tests/native/test_m23_coordinate_fixture.cpp -o "$coordinate_binary"
"$coordinate_binary" data/reference/native_coordinate_fixture.tsv \
  "$coordinate_binary_checkpoint" "$global_coordinate_checkpoint"
"$coordinate_binary" data/reference/native_coordinate_collision_fixture.tsv \
  "$coordinate_binary_checkpoint" "$global_coordinate_checkpoint"
${CXX:-g++} -std=c++20 -O2 -Wall -Wextra -Werror \
  -Isrc/native src/native/m23_kernel.cpp \
  tests/native/test_m23_bounded_walk.cpp -o "$walk_binary"
"$walk_binary" data/reference/native_bounded_walk_fixture.tsv \
  "$global_coordinate_checkpoint"
"$walk_binary" data/reference/native_bounded_walk_2500_fixture.tsv \
  "$global_coordinate_checkpoint"
