#!/usr/bin/env bash
set -euo pipefail

mkdir -p data/derived
default_output=data/derived/m23_8a_small_orbits.tsv
default_descent_output=data/derived/m23_8a_small_component_descent.tsv
default_witness_output=data/derived/m23_8a_component_witnesses.tsv
default_signature_output=data/derived/m23_8a_component_signatures.tsv
default_boundary_output=data/derived/m23_8a_boundary_incidence.tsv
default_three_point_output=data/derived/m23_8a_8a_2a_inner_classes.tsv
default_belyi_magma_output=data/derived/m23_8a_8a_2a_belyi_input.m
output="${1:-$default_output}"
mkdir -p "$(dirname "$output")"
temporary="$(mktemp)"
temporary_descent="$(mktemp)"
temporary_witness="$(mktemp)"
temporary_signature="$(mktemp)"
temporary_boundary="$(mktemp)"
temporary_three_point="$(mktemp)"
temporary_belyi_magma="$(mktemp)"
trap 'rm -f "$temporary" "$temporary_descent" "$temporary_witness" "$temporary_signature" "$temporary_boundary" "$temporary_three_point" "$temporary_belyi_magma"' EXIT

M23_OUTPUT="$temporary" \
  M23_DESCENT_OUTPUT="$temporary_descent" \
  M23_LEAN_WITNESS_OUTPUT="$temporary_witness" \
  M23_SIGNATURE_OUTPUT="$temporary_signature" \
  M23_BOUNDARY_OUTPUT="$temporary_boundary" \
  M23_THREE_POINT_OUTPUT="$temporary_three_point" \
  gap -q scripts/gap/reproduce_8A_small_orbits.g
python3 scripts/export_8a_three_point_belyi_magma.py \
  "$temporary_three_point" >"$temporary_belyi_magma"

grep -q '^base_class_vector' "$temporary"
[[ "$(grep -c '^8A' "$temporary")" -eq 1 ]]
grep -q '^full_component_id' "$temporary_descent"
[[ "$(grep -Ec '^[0-9]+[[:space:]]' "$temporary_descent")" -eq 28 ]]
[[ "$(grep -c '^T[[:space:]]' "$temporary_witness")" -eq 168 ]]
[[ "$(grep -c '^E[[:space:]]' "$temporary_witness")" -eq 504 ]]
[[ "$(grep -c '^C[[:space:]]' "$temporary_witness")" -eq 168 ]]
[[ "$(grep -Ec '^[0-9]+[[:space:]]' "$temporary_signature")" -eq 14 ]]
[[ "$(grep -Ec '^[0-9]+[[:space:]]' "$temporary_boundary")" -eq 1008 ]]
[[ "$(grep -Ec '^[0-9]+[[:space:]]' "$temporary_three_point")" -eq 28 ]]
[[ "$(grep -c '// class ' "$temporary_belyi_magma")" -eq 28 ]]
cp "$temporary" "$output"
if [[ $# -eq 0 ]]; then
  cp "$temporary_descent" "$default_descent_output"
  cp "$temporary_witness" "$default_witness_output"
  cp "$temporary_signature" "$default_signature_output"
  cp "$temporary_boundary" "$default_boundary_output"
  cp "$temporary_three_point" "$default_three_point_output"
  cp "$temporary_belyi_magma" "$default_belyi_magma_output"
  chmod 644 "$default_belyi_magma_output"
elif [[ $# -ge 2 ]]; then
  mkdir -p "$(dirname "$2")"
  cp "$temporary_descent" "$2"
  if [[ $# -ge 3 ]]; then
    mkdir -p "$(dirname "$3")"
    cp "$temporary_witness" "$3"
  fi
  if [[ $# -ge 4 ]]; then
    mkdir -p "$(dirname "$4")"
    cp "$temporary_signature" "$4"
  fi
  if [[ $# -ge 5 ]]; then
    mkdir -p "$(dirname "$5")"
    cp "$temporary_boundary" "$5"
  fi
  if [[ $# -ge 6 ]]; then
    mkdir -p "$(dirname "$6")"
    cp "$temporary_three_point" "$6"
  fi
  if [[ $# -ge 7 ]]; then
    mkdir -p "$(dirname "$7")"
    cp "$temporary_belyi_magma" "$7"
    chmod 644 "$7"
  fi
fi
if [[ "$output" == "$default_output" && $# -eq 0 ]]; then
  (
    cd data/derived
    sha256sum *.tsv *.m >SHA256SUMS
  )
fi
