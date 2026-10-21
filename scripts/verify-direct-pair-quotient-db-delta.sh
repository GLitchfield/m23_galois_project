#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 9 ]]; then
  echo "usage: $0 PAIR_CHECKPOINT BASE_DATABASE DATABASE FIRST_ORDINAL LAST_ORDINAL PROOF_LIMIT WALK_LIMIT SCHEDULE START_ORDINAL" >&2
  exit 2
fi

pair_checkpoint=$1
base_database=$2
database=$3
first_ordinal=$4
last_ordinal=$5
proof_limit=$6
walk_limit=$7
schedule=$8
start_ordinal=$9
[[ -s "$pair_checkpoint" && -s "$base_database" && -s "$database" ]] || {
  echo "missing pair checkpoint, base database, or run database" >&2
  exit 2
}
[[ "$schedule" == sequential || "$schedule" == frontier ]] || {
  echo "invalid schedule" >&2
  exit 2
}

pair_checkpoint=$(realpath "$pair_checkpoint")
base_database=$(realpath "$base_database")
database=$(realpath "$database")
progress_file=${M23_PROGRESS_FILE:-$(dirname "$database")/progress.tsv}
M23_PAIR_CHECKPOINT="$pair_checkpoint" \
M23_BASE_LEDGER_DB="$base_database" \
M23_LEDGER_DB="$database" \
M23_FIRST_ORDINAL="$first_ordinal" \
M23_LAST_ORDINAL="$last_ordinal" \
M23_ORBIT_LIMIT="$proof_limit" \
M23_WALK_LIMIT="$walk_limit" \
M23_SCAN_SCHEDULE="$schedule" \
M23_START_ORDINAL="$start_ordinal" \
M23_PROGRESS_FILE="$progress_file" \
  gap --quitonbreak -q scripts/gap/verify_direct_pair_quotient_db_delta.g
