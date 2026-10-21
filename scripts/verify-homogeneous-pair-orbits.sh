#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 CHECKPOINT" >&2
  exit 2
fi

M23_CHECKPOINT="$1" gap -q \
  scripts/gap/verify_homogeneous_pair_orbits.g
