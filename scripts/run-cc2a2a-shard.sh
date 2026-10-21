#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 4 ]]; then
  echo "usage: $0 CLASS_ORDER SHARD_COUNT SHARD_INDEX OUTPUT" >&2
  exit 2
fi

class_order=$1
shard_count=$2
shard_index=$3
output=$4
mkdir -p "$(dirname "$output")"
temporary="$(mktemp "$(dirname "$output")/.m23-shard.XXXXXX")"
trap 'rm -f "$temporary"' EXIT

M23_CLASS_ORDER="$class_order" \
M23_SHARD_COUNT="$shard_count" \
M23_SHARD_INDEX="$shard_index" \
M23_OUTPUT="$temporary" \
  gap -q scripts/gap/run_cc2a2a_shard.g

grep -q '^M23_SHARD_CHECKPOINT := rec(' "$temporary"
grep -q "  shard_index := ${shard_index}" "$temporary"
mv "$temporary" "$output"
trap - EXIT
