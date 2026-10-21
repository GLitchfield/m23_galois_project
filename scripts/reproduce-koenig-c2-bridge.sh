#!/usr/bin/env bash
set -euo pipefail

mode=${1:-write}
output=${2:-data/derived/m23_koenig_c2_bridge.tsv}

code_revision=$(
  git log -1 --format=%H -- \
    scripts/audit_koenig_c2_bridge.sage \
    scripts/gap/reproduce_koenig_2A_2A_3A_5A.g
)

arguments=(
  --orbit data/derived/m23_koenig_2a2a3a5a_orbit.tsv
  --family data/derived/m23_koenig_f19_family.tsv
  --output "$output"
  --code-revision "$code_revision"
)
if [[ "$mode" == check ]]; then
  arguments+=(--check)
elif [[ "$mode" != write ]]; then
  echo "usage: $0 [write|check] [output.tsv]" >&2
  exit 2
fi

./scripts/run-8a-sage.sh --python scripts/audit_koenig_c2_bridge.sage \
  "${arguments[@]}"
