#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
environment_file="$repo_root/sage/8a_belyi/environment.yml"
environment_prefix="${M23_SAGE_PREFIX:-$repo_root/build/sage-8a}"
dot_sage="${DOT_SAGE:-$repo_root/build/dot-sage}"
micromamba_executable="${MAMBA_EXE:-}"

if [[ -z "$micromamba_executable" ]]; then
    micromamba_executable="$(command -v micromamba || true)"
fi
if [[ -z "$micromamba_executable" ]]; then
    echo "micromamba is required; set MAMBA_EXE to its executable" >&2
    exit 2
fi

"$micromamba_executable" create \
    --yes \
    --prefix "$environment_prefix" \
    --file "$environment_file"
mkdir -p "$dot_sage"
DOT_SAGE="$dot_sage" \
    "$micromamba_executable" run --prefix "$environment_prefix" sage --version
printf 'sage_prefix=%s\n' "$environment_prefix"
printf 'dot_sage=%s\n' "$dot_sage"
