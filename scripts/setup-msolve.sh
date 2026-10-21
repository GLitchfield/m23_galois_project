#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="0.10.1"
archive_name="msolve-${version}_linux_intel_x86.zip"
archive_url="https://msolve.lip6.fr/downloads/v${version}/${archive_name}"
archive_sha256="b2ee3fdd3b84129b48c31a900bcd2a6e47bd39577fa12843798747743f074cfb"
download_dir="$repo_root/build/downloads"
install_dir="${M23_MSOLVE_PREFIX:-$repo_root/build/msolve-${version}}"
archive_path="$download_dir/$archive_name"

mkdir -p "$download_dir" "$install_dir"
if [[ ! -f "$archive_path" ]] ||
   [[ "$(sha256sum "$archive_path" | cut -d' ' -f1)" != "$archive_sha256" ]]; then
    curl -fsSL "$archive_url" -o "$archive_path"
fi

actual_sha256="$(sha256sum "$archive_path" | cut -d' ' -f1)"
if [[ "$actual_sha256" != "$archive_sha256" ]]; then
    echo "msolve archive checksum mismatch: $actual_sha256" >&2
    exit 1
fi

python3 -m zipfile -e "$archive_path" "$install_dir"
chmod u+x "$install_dir/msolve"
actual_version="$("$install_dir/msolve" -V)"
if [[ "$actual_version" != "$version" ]]; then
    echo "unexpected msolve version: $actual_version" >&2
    exit 1
fi

printf 'msolve_version=%s\n' "$actual_version"
printf 'msolve_sha256=%s\n' "$archive_sha256"
printf 'msolve_path=%s\n' "$install_dir/msolve"
