#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 0 ]]; then
  echo "usage: $0" >&2
  exit 2
fi

generated="$(mktemp -d)"
trap 'rm -rf "$generated"' EXIT
mkdir -p "$generated/data/reference"

M23_OUTPUT="$generated/data/reference/m23_classes.tsv" \
  gap -q scripts/gap/generate_m23_class_atlas.g
M23_OUTPUT="$generated/data/reference/hafner_2022_class_vectors.tsv" \
  gap -q scripts/gap/generate_hafner_class_vectors.g
./scripts/generate-homogeneous-pair-block-census.sh \
  "$generated/data/reference/m23_homogeneous_pair_block_census.tsv"

for file in m23_classes.tsv hafner_2022_class_vectors.tsv \
  m23_homogeneous_pair_block_census.tsv; do
  cmp "data/reference/$file" "$generated/data/reference/$file"
  echo "verified data/reference/$file"
done

python3 scripts/verify_reference_data.py
python3 scripts/verify_homogeneous_pair_block_census.py

(
  cd data/reference
  sha256sum -c SHA256SUMS
)
