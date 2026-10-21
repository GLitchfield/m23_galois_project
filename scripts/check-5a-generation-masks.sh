#!/usr/bin/env bash
set -euo pipefail

pair_checkpoint=${M23_PAIR_CHECKPOINT:-runs/5a-pair-orbits-v2.g}
generated_checkpoint=""
certificate=$(mktemp)
trap 'rm -f "$generated_checkpoint" "$certificate"' EXIT
if [[ ! -f "$pair_checkpoint" ]]; then
  generated_checkpoint=$(mktemp)
  ./scripts/generate-homogeneous-pair-orbits.sh 5 "$generated_checkpoint"
  pair_checkpoint=$generated_checkpoint
fi
pair_sha256=$(sha256sum "$pair_checkpoint" | cut -d' ' -f1)
M23_PAIR_CHECKPOINT="$pair_checkpoint" \
M23_PAIR_SHA256="$pair_sha256" \
M23_OUTPUT="$certificate" \
gap --quitonbreak -q scripts/gap/certify_5a_generation_masks.g
cmp data/reference/m23_5a_generation_mask_certificate.tsv "$certificate"
echo "verified exact fixed-first 5A maximal-subgroup generation masks"
