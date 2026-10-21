#!/usr/bin/env bash
set -euo pipefail

output=$(mktemp)
trap 'rm -f "$output"' EXIT
./scripts/reproduce-koenig-2a2a3a5a.sh "$output"
diff -u data/derived/m23_koenig_2a2a3a5a_orbit.tsv "$output"
python3 scripts/verify_koenig_orbit.py
