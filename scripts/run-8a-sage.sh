#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
environment_prefix="${M23_SAGE_PREFIX:-$repo_root/build/sage-8a}"
dot_sage="${DOT_SAGE:-$repo_root/build/dot-sage}"

if [[ ! -x "$environment_prefix/bin/sage" ]]; then
    echo "Sage is not installed at $environment_prefix" >&2
    echo "run ./scripts/setup-8a-sage.sh first or set M23_SAGE_PREFIX" >&2
    exit 2
fi

mkdir -p "$dot_sage"
export DOT_SAGE="$dot_sage"

if [[ "${1:-}" == "--python" ]]; then
    shift
    exec "$environment_prefix/bin/python" "$@"
fi
exec "$environment_prefix/bin/sage" "$@"
