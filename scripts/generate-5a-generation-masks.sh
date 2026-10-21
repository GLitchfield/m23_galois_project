#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 OUTPUT.bin" >&2
  exit 2
fi

output=$1
pair_checkpoint=${M23_PAIR_CHECKPOINT:-runs/5a-pair-orbits-v2.g}
generated_checkpoint=""
trap 'rm -f "$generated_checkpoint"' EXIT
if [[ ! -f "$pair_checkpoint" ]]; then
  generated_checkpoint=$(mktemp)
  ./scripts/generate-homogeneous-pair-orbits.sh 5 "$generated_checkpoint"
  pair_checkpoint=$generated_checkpoint
fi
pair_sha256=$(sha256sum "$pair_checkpoint" | cut -d' ' -f1)
M23_PAIR_CHECKPOINT="$pair_checkpoint" \
M23_PAIR_SHA256="$pair_sha256" \
M23_GIT_REVISION="$(git rev-parse HEAD)" \
M23_OUTPUT="$output" \
gap --quitonbreak -q scripts/gap/export_5a_generation_masks.g
