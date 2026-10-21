#!/usr/bin/env bash
set -euo pipefail

run_dir="$(mktemp -d)"
trap 'rm -rf "$run_dir"' EXIT
M23_JOBS=${M23_TEST_JOBS:-8} ./scripts/run-sharded-cc2a2a.sh \
  8 64 "$run_dir/run" "$run_dir/result.tsv" "$run_dir/certificate.tsv"
cmp data/derived/m23_8a_8a_2a_2a_sharded_orbit.tsv "$run_dir/result.tsv"
cmp data/derived/m23_8a_8a_2a_2a_sharded_certificate.tsv "$run_dir/certificate.tsv"
python3 scripts/verify_8a_bridge.py "$run_dir/result.tsv" "$run_dir/certificate.tsv"
(
  cd "$run_dir/run"
  sha256sum -c SHA256SUMS
)
echo "verified deterministic 64-shard 8A bridge"
