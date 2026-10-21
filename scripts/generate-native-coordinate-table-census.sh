#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 CLASS_ORDER OUTPUT" >&2
  exit 2
fi

class_order=$1
output=$2
[[ "$class_order" =~ ^[1-9][0-9]*$ ]] || {
  echo "invalid class order: $class_order" >&2
  exit 2
}
mkdir -p "$(dirname "$output")"
pair_checkpoint=$(mktemp)
temporary=$(mktemp "$(dirname "$output")/.m23-coordinate-census.XXXXXX")
trap 'rm -f "$pair_checkpoint" "$temporary"' EXIT

./scripts/generate-homogeneous-pair-orbits.sh \
  "$class_order" "$pair_checkpoint"
pair_sha256=$(sha256sum "$pair_checkpoint" | cut -d' ' -f1)
M23_PAIR_CHECKPOINT="$pair_checkpoint" M23_PAIR_SHA256="$pair_sha256" \
  M23_OUTPUT="$temporary" gap --quitonbreak -q \
  scripts/gap/generate_native_coordinate_table_census.g
mv "$temporary" "$output"
trap 'rm -f "$pair_checkpoint"' EXIT
