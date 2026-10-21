#!/usr/bin/env bash
set -euo pipefail

mkdir -p data/derived
default_output=data/derived/m23_15a_2a3_orbit.tsv
output="${1:-$default_output}"
mkdir -p "$(dirname "$output")"
temporary="$(mktemp)"
trap 'rm -f "$temporary"' EXIT

M23_OUTPUT="$temporary" \
  gap -q scripts/gap/reproduce_15A_2A3.g

expected_header=$'computed_class_number\tfixed_first_order\tfixed_first_centralizer_size'
grep -q "^${expected_header}" "$temporary"
[[ "$(grep -c '^[0-9]' "$temporary")" -eq 2 ]]
cp "$temporary" "$output"
if [[ "$output" == "$default_output" ]]; then
  (
    cd data/derived
    sha256sum *.tsv >SHA256SUMS
  )
fi
