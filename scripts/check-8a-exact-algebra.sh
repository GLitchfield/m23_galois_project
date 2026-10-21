#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export_file="$(mktemp)"
msolve_output="$(mktemp)"
trap 'rm -f "$export_file" "$msolve_output"' EXIT
cd "$repo_root"

./scripts/run-8a-sage.sh \
    data/derived/m23_8a_belyi_normalized_system.sage
export_summary="$(
    ./scripts/run-8a-sage.sh --python \
        scripts/export_8a_belyi_msolve.sage \
        --prime 13 \
        --presentation full \
        --output "$export_file"
)"
grep -F \
    'presentation=full prime=13 variables=23 equations=23 terms=1843 max_degree=15' \
    <<<"$export_summary" >/dev/null
grep -Fx \
    'alpha,a0,a1,b0,b1,c4,c2,c1,u0,u1,u2,u3,u4,u5,u6,u7,v0,v1,v2,v3,v4,v5,v6' \
    "$export_file" >/dev/null
[[ "$(sed -n '2p' "$export_file")" == "13" ]]

./scripts/run-msolve.sh \
    -f sage/8a_belyi/fixtures/msolve_linear_p13.in \
    -o "$msolve_output" \
    -t 1 \
    --random-seed 1
grep -F '[0, [13,' "$msolve_output" >/dev/null

echo "verified Sage export and msolve linear fixture"
