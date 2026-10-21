#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
environment_file="$repo_root/barth_wenz/octave/environment.yml"
environment_prefix="${M23_OCTAVE_PREFIX:-$repo_root/build/octave-sc}"
root_prefix="${M23_MAMBA_ROOT_PREFIX:-$repo_root/build/mamba-root}"
cache_prefix="${XDG_CACHE_HOME:-$repo_root/build/xdg-cache}"
micromamba_executable="${MAMBA_EXE:-}"

if [[ -z "$micromamba_executable" ]]; then
    micromamba_executable="$(command -v micromamba || true)"
fi
if [[ -z "$micromamba_executable" ]]; then
    echo "micromamba is required; set MAMBA_EXE to its executable" >&2
    exit 2
fi

XDG_CACHE_HOME="$cache_prefix" \
MAMBA_ROOT_PREFIX="$root_prefix" \
    "$micromamba_executable" create \
    --yes \
    --prefix "$environment_prefix" \
    --file "$environment_file"

XDG_CACHE_HOME="$cache_prefix" \
MAMBA_ROOT_PREFIX="$root_prefix" \
    "$micromamba_executable" run \
    --prefix "$environment_prefix" \
    octave --no-gui --quiet --eval "disp(version)"
printf 'octave_prefix=%s\n' "$environment_prefix"
