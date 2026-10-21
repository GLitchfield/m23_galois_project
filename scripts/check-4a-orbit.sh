#!/usr/bin/env bash
set -euo pipefail

generated="$(mktemp)"
trap 'rm -f "$generated"' EXIT
./scripts/reproduce-4a-orbit.sh "$generated"
cmp data/derived/m23_4a_4a_2a_2a_orbit.tsv "$generated"
python3 scripts/verify_4a_orbit.py
if [[ ${M23_SKIP_DERIVED_MANIFEST:-0} != 1 ]]; then
  ./scripts/check-data-manifests.sh derived
fi
echo "verified data/derived/m23_4a_4a_2a_2a_orbit.tsv"
