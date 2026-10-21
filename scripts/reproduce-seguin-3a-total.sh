#!/usr/bin/env bash
set -euo pipefail

output=${1:-data/derived/m23_3a_inner_nielsen_total.tsv}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
checkpoint="$work/m23_3a_pair_orbits.g"
temporary="$work/m23_3a_inner_nielsen_total.tsv"
code_revision=$(
  git log -1 --format=%H -- \
    scripts/gap/certify_3a_inner_nielsen_total.g \
    scripts/gap/generate_homogeneous_pair_orbits.g \
    src/gap/m23_homogeneous_macroblocks.g \
    src/gap/m23_maximal_subgroup_masks.g \
    src/gap/nielsen.g
)

./scripts/generate-homogeneous-pair-orbits.sh 3 "$checkpoint"
checkpoint_sha=$(sha256sum "$checkpoint" | awk '{print $1}')
M23_CODE_REVISION="$code_revision" \
M23_PAIR_CHECKPOINT="$checkpoint" \
M23_PAIR_SHA256="$checkpoint_sha" \
M23_OUTPUT="$temporary" \
  gap --quitonbreak -q scripts/gap/certify_3a_inner_nielsen_total.g

grep -q $'^generating_inner_nielsen_count\t37296$' "$temporary"
grep -q $'^generation_mask_disagreements\t0$' "$temporary"
mkdir -p "$(dirname "$output")"
mv "$temporary" "$output"
