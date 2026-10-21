#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bundle_dir="${1:-}"
environment_prefix="${M23_OCTAVE_PREFIX:-$repo_root/build/octave-sc}"
root_prefix="${M23_MAMBA_ROOT_PREFIX:-$repo_root/build/mamba-root}"
cache_prefix="${XDG_CACHE_HOME:-$repo_root/build/xdg-cache}"
micromamba_executable="${MAMBA_EXE:-}"

if [[ -z "$bundle_dir" ]]; then
    echo "usage: $0 BUNDLE_DIRECTORY" >&2
    exit 2
fi
if [[ ! -d "$bundle_dir/sc-toolbox-3.1.3" ]]; then
    echo "bundle has no pinned SC Toolbox: $bundle_dir" >&2
    exit 2
fi
if [[ -z "$micromamba_executable" ]]; then
    micromamba_executable="$(command -v micromamba || true)"
fi
if [[ -z "$micromamba_executable" ]]; then
    echo "micromamba is required; set MAMBA_EXE to its executable" >&2
    exit 2
fi

transcript="$(mktemp)"
trap 'rm -f "$transcript"' EXIT
set +e
XDG_CACHE_HOME="$cache_prefix" \
MAMBA_ROOT_PREFIX="$root_prefix" \
    "$micromamba_executable" run \
    --prefix "$environment_prefix" \
    octave --no-gui --quiet --eval \
    "addpath('$bundle_dir/sc-toolbox-3.1.3'); p=polygon([0;1;1i]); diskmap(p);" \
    >"$transcript" 2>&1
status=$?
set -e

if [[ "$status" -eq 0 ]]; then
    echo "unexpectedly constructed an SC disk map under Octave" >&2
    exit 1
fi
if ! grep -Fq "the import function is not yet implemented in Octave" \
    "$transcript"; then
    cat "$transcript" >&2
    echo "Octave failed for an unrecognized reason" >&2
    exit 1
fi
printf 'verified_octave_sc_toolbox_incompatibility=import_not_implemented\n'
