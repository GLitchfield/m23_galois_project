#!/usr/bin/env bash
set -euo pipefail

frobenius="data/derived/m23_8a_fixed_field_frobenius.tsv"
groups="data/derived/m23_degree14_transitive_group_audit.tsv"
generated_frobenius="$(mktemp)"
generated_groups="$(mktemp)"
trap 'rm -f "$generated_frobenius" "$generated_groups"' EXIT

code_revision="$(
  awk -F '\t' '$1 == "# code_revision" { print $2 }' "$frobenius"
)"
M23_CODE_REVISION="$code_revision" \
  ./scripts/reproduce-8a-fixed-field-galois.sh \
  data/derived/m23_8a_class1_degree14_descended_cover.json \
  "$generated_frobenius" \
  "$generated_groups"

cmp "$frobenius" "$generated_frobenius"
cmp "$groups" "$generated_groups"
python3 scripts/check_8a_fixed_field_galois.py "$frobenius" "$groups"
