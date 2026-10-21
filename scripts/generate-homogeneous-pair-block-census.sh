#!/usr/bin/env bash
set -euo pipefail

output=${1:-data/reference/m23_homogeneous_pair_block_census.tsv}
mkdir -p "$(dirname "$output")"
temporary="$(mktemp "$(dirname "$output")/.m23-pair-census.XXXXXX")"
trap 'rm -f "$temporary"' EXIT

M23_OUTPUT="$temporary" gap -q \
  scripts/gap/generate_homogeneous_pair_block_census.g
grep -q '^target_class' "$temporary"
[[ "$(grep -c '^4A' "$temporary")" -eq 12 ]]
[[ "$(grep -c '^5A' "$temporary")" -eq 12 ]]
mv "$temporary" "$output"
trap - EXIT
