#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="0.10.1"
msolve_executable="${M23_MSOLVE:-$repo_root/build/msolve-${version}/msolve}"

if [[ ! -x "$msolve_executable" ]]; then
    echo "msolve is not installed at $msolve_executable" >&2
    echo "run ./scripts/setup-msolve.sh first or set M23_MSOLVE" >&2
    exit 2
fi

exec "$msolve_executable" "$@"
