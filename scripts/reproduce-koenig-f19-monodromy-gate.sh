#!/usr/bin/env bash
set -euo pipefail

mode=${1:-write}
candidate_output=${2:-data/derived/m23_koenig_f19_monodromy_candidates.tsv}
census_output=${3:-data/derived/m23_koenig_f19_frobenius.tsv}
gate_output=${4:-data/derived/m23_koenig_f19_transitivity_gate.tsv}

candidate_temporary=$(mktemp)
trap 'rm -f "$candidate_temporary"' EXIT

code_revision=$(
  git log -1 --format=%H -- \
    scripts/gap/audit_koenig_f19_monodromy_candidates.g \
    scripts/audit_koenig_f19_monodromy.sage \
    src/gap/m23_fixed_first.g \
    src/gap/nielsen.g \
    data/reference/m23_classes.tsv
)

M23_CODE_REVISION="$code_revision" \
M23_OUTPUT="$candidate_temporary" \
  gap --quitonbreak -q scripts/gap/audit_koenig_f19_monodromy_candidates.g

if [[ "$mode" == check ]]; then
  diff -u "$candidate_output" "$candidate_temporary"
  ./scripts/run-8a-sage.sh --python scripts/audit_koenig_f19_monodromy.sage \
    --candidates "$candidate_output" \
    --census "$census_output" \
    --gate "$gate_output" \
    --code-revision "$code_revision" \
    --check
elif [[ "$mode" == write ]]; then
  mkdir -p "$(dirname "$candidate_output")"
  mv "$candidate_temporary" "$candidate_output"
  ./scripts/run-8a-sage.sh --python scripts/audit_koenig_f19_monodromy.sage \
    --candidates "$candidate_output" \
    --census "$census_output" \
    --gate "$gate_output" \
    --code-revision "$code_revision"
else
  echo "usage: $0 [write|check] [candidate.tsv census.tsv gate.tsv]" >&2
  exit 2
fi
