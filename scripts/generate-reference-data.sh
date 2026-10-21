#!/usr/bin/env bash
set -euo pipefail

mkdir -p data/reference
M23_OUTPUT=data/reference/m23_classes.tsv \
  gap -q scripts/gap/generate_m23_class_atlas.g
M23_OUTPUT=data/reference/hafner_2022_class_vectors.tsv \
  gap -q scripts/gap/generate_hafner_class_vectors.g
./scripts/generate-homogeneous-pair-block-census.sh
(
  cd data/reference
  sha256sum *.tsv >SHA256SUMS
)
