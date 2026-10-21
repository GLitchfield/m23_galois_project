#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 11 ]]; then
  echo "usage: $0 DATABASE ORDINAL TARGET_ORDER PAIR_SCHEMA MACROBLOCK_COUNT FIRST LAST PROOF_LIMIT WALK_LIMIT SCHEDULE START_ORDINAL" >&2
  exit 2
fi

database=$(realpath "$1")
M23_LEDGER_DB="$database" M23_SPECIAL_ORDINAL="$2" \
M23_TARGET_ORDER="$3" M23_PAIR_SCHEMA="$4" M23_MACROBLOCK_COUNT="$5" \
M23_FIRST_ORDINAL="$6" M23_LAST_ORDINAL="$7" M23_ORBIT_LIMIT="$8" \
M23_WALK_LIMIT="$9" M23_SCAN_SCHEDULE="${10}" \
M23_START_ORDINAL="${11}" M23_TRAVERSAL_ORDER="legacy" \
  gap --quitonbreak -q scripts/gap/enqueue_special_quotient_block.g
