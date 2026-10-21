#!/usr/bin/env bash
set -euo pipefail

checkpoint=$(mktemp)
run_dir=$(mktemp -d)
trap 'rm -f "$checkpoint"; rm -rf "$run_dir"' EXIT
printf 'placeholder\n' >"$checkpoint"

set +e
M23_MIN_AVAILABLE_MIB=999999999 \
  ./scripts/run-db-quotient-workers.sh "$checkpoint" \
  1 1 1 1 1 "$run_dir" 1 1 >/dev/null 2>&1
status=$?
set -e

if [[ $status -ne 75 ]]; then
  echo "resource guard returned $status instead of 75" >&2
  exit 1
fi
if [[ -e "$run_dir/ledger.sqlite3" ]]; then
  echo "resource guard initialized a ledger before refusing work" >&2
  exit 1
fi

set +e
M23_WORKER_OFFSET=invalid M23_MIN_AVAILABLE_MIB=0 \
  ./scripts/run-db-quotient-workers.sh "$checkpoint" \
  1 1 1 1 1 "$run_dir" 1 1 >/dev/null 2>&1
status=$?
set -e
if [[ $status -ne 2 ]]; then
  echo "worker offset validation returned $status instead of 2" >&2
  exit 1
fi

set +e
M23_MIN_AVAILABLE_MIB=999999999 \
  ./scripts/run-parallel-quotient-delta-verification.sh \
  "$checkpoint" "$run_dir/base.sqlite3" "$run_dir/base.json" \
  1 1 1 1 1 "$run_dir" 1 1 frontier >/dev/null 2>&1
status=$?
set -e

if [[ $status -ne 75 ]]; then
  echo "replay resource guard returned $status instead of 75" >&2
  exit 1
fi
if [[ -e "$run_dir/parallel-certificate-plan.json" ]]; then
  echo "replay resource guard planned work before refusing it" >&2
  exit 1
fi
