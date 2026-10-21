#!/usr/bin/env bash
set -euo pipefail

scope=${1:-all}

check_manifest() {
  local directory=$1
  local count
  (
    cd "$directory"
    sha256sum --quiet -c SHA256SUMS
  )
  count=$(wc -l <"$directory/SHA256SUMS")
  echo "verified $count SHA-256 entries under $directory"
}

case "$scope" in
  reference)
    check_manifest data/reference
    ;;
  derived)
    check_manifest data/derived
    ;;
  all)
    check_manifest data/reference
    check_manifest data/derived
    ;;
  *)
    echo "usage: $0 [reference|derived|all]" >&2
    exit 2
    ;;
esac
