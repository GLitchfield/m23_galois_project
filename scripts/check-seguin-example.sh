#!/usr/bin/env bash
set -euo pipefail

output=$(mktemp)
trap 'rm -f "$output"' EXIT
gap --quitonbreak -q scripts/gap/check_seguin_m23_example.g >"$output"
diff -u data/reference/seguin_2025_m23_example.tsv "$output"
echo "Seguin M23 example verified"
