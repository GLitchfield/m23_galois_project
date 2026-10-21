#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "usage: $0 PAIR_CHECKPOINT LEDGER_DB [OUTPUT_TSV]" >&2
  exit 2
fi

pair_checkpoint=$(realpath "$1")
ledger_db=$(realpath "$2")
output_tsv=${3:-$(dirname "$ledger_db")/complete-4a-audit.tsv}

M23_PAIR_CHECKPOINT="$pair_checkpoint" \
M23_LEDGER_DB="$ledger_db" \
M23_CLOSED_CERTIFICATES="781,1396,15731" \
M23_AUDIT_OUTPUT="$output_tsv" \
  gap --quitonbreak -q scripts/gap/audit_complete_4a_bounded_search.g
