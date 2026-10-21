#!/usr/bin/env bash
set -euo pipefail

run_dir="$(mktemp -d)"
trap 'rm -rf "$run_dir"' EXIT
M23_JOBS=${M23_TEST_JOBS:-4} ./scripts/run-sharded-cc2a2a.sh \
  5 16 "$run_dir/bridge" "$run_dir/bridge-result.tsv" \
  "$run_dir/bridge-certificate.tsv"
./scripts/derive-homogeneous-bridge-orbit.sh \
  5 16 "$run_dir/bridge" "$run_dir/homogeneous.tsv"
cmp data/derived/m23_5a_homogeneous_bridge_orbit.tsv \
  "$run_dir/homogeneous.tsv"
python3 scripts/verify_homogeneous_bridge.py "$run_dir/homogeneous.tsv" 5
echo "verified deterministic 5A bridge-to-homogeneous construction"
