#!/usr/bin/env bash
set -euo pipefail

generated_certificate="$(mktemp)"
generated_tuple_certificate="$(mktemp)"
trap 'rm -f "$generated_certificate" "$generated_tuple_certificate"' EXIT
python3 scripts/generate_8a_descent_lean_certificate.py >"$generated_certificate"
cmp formal/M23Formal/Certificates/Test0056Data.lean "$generated_certificate"
python3 scripts/generate_8a_tuple_lean_certificate.py >"$generated_tuple_certificate"
cmp formal/M23Formal/Certificates/Test0058Data.lean "$generated_tuple_certificate"

if rg -n '\b(sorry|admit|axiom|native_decide)\b' \
    formal/M23Formal formal/M23Formal.lean \
    --glob '!Audit.lean'; then
  echo "error: forbidden unproved declaration in project Lean sources" >&2
  exit 1
fi

(
  cd formal
  lean --version
  lake --version
  lake build
  lake env lean M23Formal/Audit.lean
)

echo "Lean Hurwitz kernel and test-0056/test-0058/test-0099 certificates verified"
