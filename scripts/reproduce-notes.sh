#!/usr/bin/env bash
set -euo pipefail

mode="${1:-write}"
if [[ "$mode" != "write" && "$mode" != "--check" ]]; then
  echo "usage: $0 [--check]" >&2
  exit 2
fi

files=(gap_m23_basic_data gap_degree23_transitive_groups)
for name in "${files[@]}"; do
  expected="notes/${name}.txt"
  generated="$(mktemp)"
  trap 'rm -f "$generated"' EXIT
  gap -q "notes/${name}.g" >"$generated"

  if [[ "$mode" == "--check" ]]; then
    if ! cmp -s "$expected" "$generated"; then
      echo "error: $expected is not reproducible; run 'make reproduce-notes' and inspect the diff" >&2
      diff -u "$expected" "$generated" || true
      exit 1
    fi
    echo "verified $expected"
  else
    cp "$generated" "$expected"
    echo "wrote $expected"
  fi

  rm -f "$generated"
  trap - EXIT
done

