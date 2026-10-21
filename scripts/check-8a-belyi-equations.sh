#!/usr/bin/env bash
set -euo pipefail

generated_magma="$(mktemp)"
generated_sage="$(mktemp)"
probe="$(mktemp)"
trap 'rm -f "$generated_magma" "$generated_sage" "$probe"' EXIT

python3 scripts/generate_8a_belyi_equations.py >"$generated_magma"
python3 scripts/generate_8a_belyi_equations.py --format sage >"$generated_sage"
cmp data/derived/m23_8a_belyi_normalized_system.m "$generated_magma"
cmp data/derived/m23_8a_belyi_normalized_system.sage "$generated_sage"
python3 scripts/search_8a_belyi_modp.py --prime 3 >"$probe"
grep -Fx 'p=3 tested=4374 raw_gcd8=0 valid=0' "$probe" >/dev/null
echo "verified Magma/Sage 8A Belyi equations and characteristic-3 probe"
