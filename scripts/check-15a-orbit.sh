#!/usr/bin/env bash
set -euo pipefail

generated="$(mktemp)"
trap 'rm -f "$generated"' EXIT
./scripts/reproduce-15a-orbit.sh "$generated"
cmp data/derived/m23_15a_2a3_orbit.tsv "$generated"
python3 scripts/verify_15a_orbit.py
if [[ ${M23_SKIP_DERIVED_MANIFEST:-0} != 1 ]]; then
  ./scripts/check-data-manifests.sh derived
fi
echo "verified data/derived/m23_15a_2a3_orbit.tsv"
