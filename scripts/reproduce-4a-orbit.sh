#!/usr/bin/env bash
set -euo pipefail

mkdir -p data/derived
default_output=data/derived/m23_4a_4a_2a_2a_orbit.tsv
output="${1:-$default_output}"
mkdir -p "$(dirname "$output")"
temporary="$(mktemp)"
trap 'rm -f "$temporary"' EXIT

M23_OUTPUT="$temporary" \
  gap -q scripts/gap/reproduce_4A_4A_2A_2A.g

grep -q '^class_vector' "$temporary"
[[ "$(grep -c '^4A' "$temporary")" -eq 1 ]]
cp "$temporary" "$output"
if [[ "$output" == "$default_output" ]]; then
  (
    cd data/derived
    sha256sum *.tsv >SHA256SUMS
  )
fi
