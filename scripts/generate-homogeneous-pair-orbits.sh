#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 CLASS_ORDER OUTPUT" >&2
  exit 2
fi

class_order=$1
output=$2
mkdir -p "$(dirname "$output")"
temporary="$(mktemp "$(dirname "$output")/.m23-pair-orbits.XXXXXX")"
trap 'rm -f "$temporary"' EXIT

M23_CLASS_ORDER="$class_order" M23_OUTPUT="$temporary" \
  gap -q scripts/gap/generate_homogeneous_pair_orbits.g
grep -q '^M23_PAIR_BLOCK_CHECKPOINT := rec(' "$temporary"
grep -q "target_order := ${class_order}" "$temporary"
mv "$temporary" "$output"
trap - EXIT
