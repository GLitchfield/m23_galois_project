#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 13 ]]; then
  echo "usage: $0 PAIR_CHECKPOINT DATABASE FIRST LAST PROOF_LIMIT WALK_LIMIT SCHEDULE START_ORDINAL SEGMENT_INDEX SEGMENT_COUNT FIRST_CERTIFICATE LAST_CERTIFICATE PLAN_ID" >&2
  exit 2
fi

pair_checkpoint=$(realpath "$1")
database=$(realpath "$2")
progress_file=${M23_PROGRESS_FILE:-$(dirname "$database")/progress.tsv}
M23_PAIR_CHECKPOINT="$pair_checkpoint" M23_LEDGER_DB="$database" \
M23_FIRST_ORDINAL="$3" M23_LAST_ORDINAL="$4" M23_ORBIT_LIMIT="$5" \
M23_WALK_LIMIT="$6" M23_SCAN_SCHEDULE="$7" M23_START_ORDINAL="$8" \
M23_SEGMENT_INDEX="$9" M23_SEGMENT_COUNT="${10}" \
M23_FIRST_CERTIFICATE="${11}" M23_LAST_CERTIFICATE="${12}" \
M23_VERIFICATION_PLAN="${13}" M23_PROGRESS_FILE="$progress_file" \
  gap --quitonbreak -q scripts/gap/verify_direct_pair_quotient_certificate_segment.g
