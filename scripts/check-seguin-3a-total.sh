#!/usr/bin/env bash
set -euo pipefail

output=$(mktemp)
trap 'rm -f "$output"' EXIT
./scripts/reproduce-seguin-3a-total.sh "$output"
diff -u data/derived/m23_3a_inner_nielsen_total.tsv "$output"
echo "complete 3A inner Nielsen total verified"
