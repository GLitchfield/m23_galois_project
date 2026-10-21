#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "usage: $0 ARCHIVE METHOD [TIMEOUT_SECONDS] [PRIME]" >&2
  echo "methods: plane-qq, plane-mod-p, function-field" >&2
  exit 2
fi

archive=$1
method=$2
timeout_seconds=${3:-3600}
prime=${4:-11}

args=(
  --python
  scripts/probe_koenig_normalization_genus.sage
  "$archive"
  --method "$method"
)
if [[ "$method" == "plane-mod-p" ]]; then
  args+=(--prime "$prime")
fi

timeout "$timeout_seconds" ./scripts/run-8a-sage.sh "${args[@]}"
