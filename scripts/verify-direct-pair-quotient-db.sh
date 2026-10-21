#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 8 ]]; then
  echo "usage: $0 PAIR_CHECKPOINT DATABASE FIRST_ORDINAL LAST_ORDINAL PROOF_LIMIT WALK_LIMIT SCHEDULE START_ORDINAL" >&2
  exit 2
fi

pair_checkpoint=$1
database=$2
first_ordinal=$3
last_ordinal=$4
proof_limit=$5
walk_limit=$6
schedule=$7
start_ordinal=$8
[[ -s "$pair_checkpoint" ]] || { echo "missing pair checkpoint" >&2; exit 2; }
[[ -s "$database" ]] || { echo "missing ledger database" >&2; exit 2; }
[[ "$schedule" == sequential || "$schedule" == frontier ]] || { echo "invalid schedule" >&2; exit 2; }

pair_checkpoint=$(realpath "$pair_checkpoint")
database=$(realpath "$database")
progress_file=${M23_PROGRESS_FILE:-$(dirname "$database")/progress.tsv}
M23_PAIR_CHECKPOINT="$pair_checkpoint" \
M23_LEDGER_DB="$database" \
M23_FIRST_ORDINAL="$first_ordinal" \
M23_LAST_ORDINAL="$last_ordinal" \
M23_ORBIT_LIMIT="$proof_limit" \
M23_WALK_LIMIT="$walk_limit" \
M23_SCAN_SCHEDULE="$schedule" \
M23_START_ORDINAL="$start_ordinal" \
M23_PROGRESS_FILE="$progress_file" \
  gap --quitonbreak -q scripts/gap/verify_direct_pair_quotient_db.g
