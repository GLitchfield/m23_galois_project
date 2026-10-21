#!/usr/bin/env bash
set -euo pipefail

run_dir="$(mktemp -d)"
trap 'rm -rf "$run_dir"' EXIT
M23_JOBS=${M23_TEST_JOBS:-2} ./scripts/run-sharded-cc2a2a.sh \
  4 4 "$run_dir/run" "$run_dir/result.tsv" "$run_dir/certificate.tsv"
cmp data/derived/m23_4a_sharded_orbit.tsv "$run_dir/result.tsv"
cmp data/derived/m23_4a_sharded_certificate.tsv "$run_dir/certificate.tsv"
python3 scripts/verify_sharded_4a.py "$run_dir/result.tsv" "$run_dir/certificate.tsv"
(
  cd "$run_dir/run"
  sha256sum -c SHA256SUMS
)
resume_log="$(M23_JOBS=2 ./scripts/run-sharded-cc2a2a.sh \
  4 4 "$run_dir/run" "$run_dir/result-resumed.tsv" "$run_dir/certificate-resumed.tsv")"
[[ "$(grep -c '^resume: keeping ' <<<"$resume_log")" -eq 4 ]]
cmp "$run_dir/result.tsv" "$run_dir/result-resumed.tsv"
cmp "$run_dir/certificate.tsv" "$run_dir/certificate-resumed.tsv"
./scripts/derive-homogeneous-bridge-orbit.sh \
  4 4 "$run_dir/run" "$run_dir/homogeneous.tsv"
python3 scripts/verify_homogeneous_bridge.py "$run_dir/homogeneous.tsv" 4
./scripts/generate-homogeneous-pair-orbits.sh 4 "$run_dir/pair-orbits.g"
./scripts/verify-homogeneous-pair-orbits.sh "$run_dir/pair-orbits.g"
M23_PAIR_CHECKPOINT="$run_dir/pair-orbits.g" \
M23_BRIDGE_CHECKPOINT="$run_dir/run/shard-1-of-4.g" \
  gap -q scripts/gap/check_bounded_orbit_engine.g
M23_PAIR_CHECKPOINT="$run_dir/pair-orbits.g" \
  gap -q scripts/gap/check_direct_pair_coordinates.g >/dev/null
./scripts/scan-direct-pair-quotient.sh "$run_dir/pair-orbits.g" \
  1633430 1633430 2500 "$run_dir/quotient-scan" >/dev/null
./scripts/verify-direct-pair-quotient-scan.sh "$run_dir/pair-orbits.g" \
  "$run_dir/quotient-scan/scan.g" >/dev/null
./scripts/scan-direct-pair-quotient-db.sh "$run_dir/pair-orbits.g" \
  2 7928185 2500 "$run_dir/frontier-db-scan" frontier 1633430 2 >/dev/null
./scripts/verify-direct-pair-quotient-db.sh "$run_dir/pair-orbits.g" \
  "$run_dir/frontier-db-scan/ledger.sqlite3" \
  2 7928185 2500 2500 frontier 1633430 >/dev/null
M23_PAIR_CHECKPOINT="$run_dir/pair-orbits.g" \
  gap -q scripts/gap/probe_macroblock_quotient.g >/dev/null
status_output="$(python3 scripts/m23_run_status.py "$run_dir/run")"
grep -q 'checkpoints: 4/4' <<<"$status_output"
grep -q 'representative verification: 4/4' <<<"$status_output"
grep -q 'deep shard recount: 4/4' <<<"$status_output"
grep -q 'merge result: complete' <<<"$status_output"
echo "verified deterministic four-shard engine"
