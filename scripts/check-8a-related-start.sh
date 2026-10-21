#!/usr/bin/env bash
set -euo pipefail

summary=data/derived/m23_8a_related_start_boundaries.tsv
revision="$(awk -F '\t' '$1 == "# code_revision" { print $2; exit }' "$summary")"
if [[ ! "$revision" =~ ^[0-9a-f]{40}$ ]]; then
  echo "invalid related-start code revision" >&2
  exit 1
fi
# The recorded revision belongs to the private development history. When it
# is present (for example in the original repository), require the producers
# to be unchanged since that revision; in a fresh-history clone, skip this
# provenance check and rely on the byte-for-byte regeneration below.
if git cat-file -e "${revision}^{commit}" 2>/dev/null; then
  git merge-base --is-ancestor "$revision" HEAD
  git diff --quiet "$revision" -- \
    scripts/gap/audit_8a_related_start_boundaries.g \
    scripts/gap/generate_8a_related_start_source_classes.g \
    scripts/check_8a_related_start_evidence.py \
    scripts/export_8a_related_start_magma.py \
    scripts/reproduce-8a-related-start.sh
else
  echo "note: recorded revision $revision is not in this history; skipping ancestry check" >&2
fi

temporary_dir="$(mktemp -d)"
trap 'rm -rf "$temporary_dir"' EXIT
M23_CODE_REVISION="$revision" scripts/reproduce-8a-related-start.sh "$temporary_dir"

for name in \
  m23_8a_related_start_boundaries.tsv \
  m23_8a_related_start_target_coverage.tsv \
  m23_4a_3a_8a_inner_classes.tsv \
  m23_8a_related_start_links.tsv \
  m23_4a_3a_8a_belyi_input.m
do
  cmp "data/derived/$name" "$temporary_dir/$name"
done

python3 scripts/check_8a_related_start_evidence.py
echo "verified exact 8A related-start boundary evidence"
