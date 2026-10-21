#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "usage: $0 PAIR_CHECKPOINT OUTPUT [PROGRESS]" >&2
  exit 2
fi
pair_checkpoint=$(realpath "$1")
output=$2
progress=${3:-$(dirname "$output")/native-coordinate-export-progress.tsv}
[[ -s "$pair_checkpoint" ]] || { echo "missing pair checkpoint" >&2; exit 2; }
[[ ! -e "$output" && ! -e "$output.manifest.tsv" ]] || {
  echo "coordinate checkpoint destination must be new" >&2
  exit 2
}
mkdir -p "$(dirname "$output")"
temporary=$(mktemp "$(dirname "$output")/.m23-coordinate.XXXXXX")
trap 'rm -f "$temporary"' EXIT
pair_sha256=$(sha256sum "$pair_checkpoint" | cut -d' ' -f1)
git_revision=$(git rev-parse HEAD)
M23_PAIR_CHECKPOINT="$pair_checkpoint" \
M23_PAIR_SHA256="$pair_sha256" M23_GIT_REVISION="$git_revision" \
M23_OUTPUT="$temporary" M23_PROGRESS_FILE="$progress" \
  gap --quitonbreak -q scripts/gap/export_native_coordinate_checkpoint.g
mv "$temporary" "$output"
trap - EXIT
{
  echo -e "sha256\t$(sha256sum "$output" | cut -d' ' -f1)"
  ./scripts/check-native-coordinate-checkpoint.sh "$output"
} >"$output.manifest.tsv"
cat "$output.manifest.tsv"
