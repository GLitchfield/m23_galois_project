#!/usr/bin/env bash
set -euo pipefail

output=$(mktemp)
trap 'rm -f "$output"' EXIT
./scripts/reproduce-seguin-3a-components.sh "$output"
diff -u data/derived/m23_seguin_3a_component_reconciliation.tsv "$output"
echo "Seguin 3A component reconciliation verified"
