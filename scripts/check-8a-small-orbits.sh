#!/usr/bin/env bash
set -euo pipefail

generated="$(mktemp)"
generated_descent="$(mktemp)"
generated_witness="$(mktemp)"
generated_signature="$(mktemp)"
generated_boundary="$(mktemp)"
generated_three_point="$(mktemp)"
generated_belyi_magma="$(mktemp)"
trap 'rm -f "$generated" "$generated_descent" "$generated_witness" "$generated_signature" "$generated_boundary" "$generated_three_point" "$generated_belyi_magma"' EXIT
./scripts/reproduce-8a-small-orbits.sh "$generated" "$generated_descent" \
  "$generated_witness" "$generated_signature" "$generated_boundary" \
  "$generated_three_point" "$generated_belyi_magma"
cmp data/derived/m23_8a_small_orbits.tsv "$generated"
cmp data/derived/m23_8a_small_component_descent.tsv "$generated_descent"
cmp data/derived/m23_8a_component_witnesses.tsv "$generated_witness"
cmp data/derived/m23_8a_component_signatures.tsv "$generated_signature"
cmp data/derived/m23_8a_boundary_incidence.tsv "$generated_boundary"
cmp data/derived/m23_8a_8a_2a_inner_classes.tsv "$generated_three_point"
cmp data/derived/m23_8a_8a_2a_belyi_input.m "$generated_belyi_magma"
python3 scripts/verify_8a_small_orbits.py
if [[ ${M23_SKIP_DERIVED_MANIFEST:-0} != 1 ]]; then
  ./scripts/check-data-manifests.sh derived
fi
echo "verified data/derived/m23_8a_small_orbits.tsv"
