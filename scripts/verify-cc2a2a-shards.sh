#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 4 ]]; then
  echo "usage: $0 CLASS_ORDER SHARD_COUNT RUN_DIR OUTPUT" >&2
  exit 2
fi

class_order=$1
shard_count=$2
run_dir=$3
output=$4
checkpoints=()
for ((index = 1; index <= shard_count; index++)); do
  checkpoint="$run_dir/shard-${index}-of-${shard_count}.g"
  [[ -s "$checkpoint" ]] || { echo "missing checkpoint: $checkpoint" >&2; exit 1; }
  checkpoints+=("$checkpoint")
done
checkpoint_list="$(IFS=:; echo "${checkpoints[*]}")"
mkdir -p "$(dirname "$output")"
temporary="$(mktemp "$(dirname "$output")/.m23-certificate.XXXXXX")"
trap 'rm -f "$temporary"' EXIT

M23_CLASS_ORDER="$class_order" \
M23_SHARD_COUNT="$shard_count" \
M23_CHECKPOINTS="$checkpoint_list" \
M23_OUTPUT="$temporary" \
  gap -q scripts/gap/verify_cc2a2a_shards.g

grep -q '^schema_version' "$temporary"
grep -q $'^1\ttrue\t'"${class_order}"$'\t'"${shard_count}"$'\t' "$temporary"
mv "$temporary" "$output"
trap - EXIT
