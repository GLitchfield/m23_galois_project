#!/usr/bin/env bash
set -euo pipefail

output=${1:-data/derived/m23_seguin_3a_component_reconciliation.tsv}
mkdir -p "$(dirname "$output")"
temporary=$(mktemp "$(dirname "$output")/.m23-seguin-3a.XXXXXX")
trap 'rm -f "$temporary"' EXIT

code_revision=$(
  git log -1 --format=%H -- \
    scripts/gap/reconcile_seguin_3a_components.g \
    src/gap/nielsen.g
)

M23_CODE_REVISION="$code_revision" \
M23_OUTPUT="$temporary" \
  gap --quitonbreak -q scripts/gap/reconcile_seguin_3a_components.g

grep -q '^component' "$temporary"
grep -q $'^both_full_braid_components_contain_inverse_pairs\ttrue$' "$temporary"
mv "$temporary" "$output"
trap - EXIT
