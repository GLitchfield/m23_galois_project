#!/usr/bin/env bash
set -euo pipefail

output_dir="${1:-data/derived}"
target=data/derived/m23_8a_8a_2a_inner_classes.tsv
revision="${M23_CODE_REVISION:-$(git rev-parse HEAD)}"
target_sha256="$(sha256sum "$target" | cut -d ' ' -f 1)"
temporary_dir="$(mktemp -d)"
trap 'rm -rf "$temporary_dir"' EXIT

summary="$temporary_dir/m23_8a_related_start_boundaries.tsv"
coverage="$temporary_dir/m23_8a_related_start_target_coverage.tsv"
sources="$temporary_dir/m23_4a_3a_8a_inner_classes.tsv"
links="$temporary_dir/m23_8a_related_start_links.tsv"
magma="$temporary_dir/m23_4a_3a_8a_belyi_input.m"

M23_CODE_REVISION="$revision" \
  M23_TARGET_SHA256="$target_sha256" \
  M23_RELATED_START_OUTPUT="$summary" \
  M23_RELATED_START_COVERAGE_OUTPUT="$coverage" \
  gap -q scripts/gap/audit_8a_related_start_boundaries.g

M23_CODE_REVISION="$revision" \
  M23_TARGET_SHA256="$target_sha256" \
  M23_RELATED_SOURCE_OUTPUT="$sources" \
  M23_RELATED_LINK_OUTPUT="$links" \
  gap -q scripts/gap/generate_8a_related_start_source_classes.g

python3 scripts/check_8a_related_start_evidence.py \
  --target "$target" --summary "$summary" --coverage "$coverage" \
  --sources "$sources" --links "$links"
python3 scripts/export_8a_related_start_magma.py "$sources" >"$magma"

mkdir -p "$output_dir"
cp "$summary" "$coverage" "$sources" "$links" "$magma" "$output_dir/"
chmod 644 "$output_dir/m23_4a_3a_8a_belyi_input.m"

if [[ "$output_dir" == data/derived ]]; then
  (
    cd data/derived
    sha256sum ./*.tsv ./*.m >SHA256SUMS
  )
fi

echo "wrote exact 8A related-start evidence to $output_dir"
