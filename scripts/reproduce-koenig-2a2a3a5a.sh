#!/usr/bin/env bash
set -euo pipefail

default_output=data/derived/m23_koenig_2a2a3a5a_orbit.tsv
output=${1:-$default_output}
temporary=$(mktemp)
trap 'rm -f "$temporary"' EXIT

code_revision=$(
  git log -1 --format=%H -- \
    scripts/gap/reproduce_koenig_2A_2A_3A_5A.g \
    src/gap/m23_fixed_first.g \
    src/gap/nielsen.g
)

M23_CODE_REVISION="$code_revision" \
M23_OUTPUT="$temporary" \
  gap --quitonbreak -q scripts/gap/reproduce_koenig_2A_2A_3A_5A.g

grep -q $'^3A,5A,2A,2A\t1526400\t8490\t980\t1\t980\t119\t1\t980\t43\t' \
  "$temporary"
mkdir -p "$(dirname "$output")"
mv "$temporary" "$output"
