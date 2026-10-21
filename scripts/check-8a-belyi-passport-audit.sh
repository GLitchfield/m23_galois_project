#!/usr/bin/env bash
set -euo pipefail

output="$(mktemp)"
trap 'rm -f "$output"' EXIT

gap -q scripts/gap/audit_8a_belyi_passport_mass.g >"$output"

grep -Fx 's23_weighted_orbit_mass=1024815269/1024' "$output" >/dev/null
grep -Fx 'm23_weighted_orbit_mass=491/8' "$output" >/dev/null
echo "verified 8A Belyi ambient and M23 passport masses"
