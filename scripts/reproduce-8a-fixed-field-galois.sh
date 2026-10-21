#!/usr/bin/env bash
set -euo pipefail

source_json="${1:-data/derived/m23_8a_class1_degree14_descended_cover.json}"
frobenius_output="${2:-data/derived/m23_8a_fixed_field_frobenius.tsv}"
group_output="${3:-data/derived/m23_degree14_transitive_group_audit.tsv}"
code_revision="${M23_CODE_REVISION:-$(git rev-parse HEAD)}"

./scripts/run-8a-sage.sh --python \
  scripts/analyze_8a_fixed_field_frobenius.sage \
  "$source_json" \
  --code-revision "$code_revision" \
  --output "$frobenius_output"

M23_CODE_REVISION="$code_revision" \
M23_GROUP_AUDIT_OUTPUT="$group_output" \
  gap -q scripts/gap/audit_degree14_transitive_groups.g
