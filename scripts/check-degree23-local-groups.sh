#!/usr/bin/env bash
set -euo pipefail

output="$(mktemp)"
trap 'rm -f "$output"' EXIT

gap -q scripts/gap/audit_degree23_local_groups.g >"$output"
grep -Fx 'degree23_transitive_groups=7' "$output" >/dev/null
grep -Fx '23T3_order=253 structure=C23 : C11' "$output" >/dev/null
grep -Fx '23T4_order=506 structure=C23 : C22' "$output" >/dev/null
grep -Fx 'solvable_transitive_subgroups_of_M23=23T1,23T3' "$output" >/dev/null
echo "verified the degree-23 local decomposition-group filter"
