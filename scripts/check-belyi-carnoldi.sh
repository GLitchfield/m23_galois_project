#!/usr/bin/env bash
# Build and self-test the CArnoldi helper from the pinned external Belyi tree.
set -uo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "usage: $0 BELYI_CHECKOUT NEW_OUTPUT_DIRECTORY [DEPENDENCY_PREFIX]" >&2
  exit 2
fi

belyi_checkout=$1
output_dir=$2
dependency_prefix=${3:-}
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
project_root=$(cd "$script_dir/.." && pwd)
pinned_revision=f6f78dc2950343fcd9894c334f9a58f3ab065843
pinned_source_sha256=f304ff6a2e93f7c1ea31f69082623167ccdc70b9f8564eed1588932ec63d5a5b
pinned_makefile_sha256=81af12b542ad88a8b5ab1bb9f9131787362e9d16f32280a8b779d59e72cb4bf9

for command in git make gcc readelf sha256sum; do
  command -v "$command" >/dev/null 2>&1 || {
    echo "required command not found: $command" >&2
    exit 2
  }
done
[[ ! -e "$output_dir" ]] || {
  echo "output directory must not already exist" >&2
  exit 2
}
git -C "$belyi_checkout" rev-parse --git-dir >/dev/null 2>&1 || {
  echo "Belyi checkout is not a Git repository" >&2
  exit 2
}
actual_revision=$(git -C "$belyi_checkout" rev-parse HEAD) || exit 2
[[ "$actual_revision" == "$pinned_revision" ]] || {
  echo "Belyi revision mismatch: expected $pinned_revision, got $actual_revision" >&2
  exit 2
}
dirty=$(git -C "$belyi_checkout" status --porcelain) || exit 2
[[ -z "$dirty" ]] || {
  echo "Belyi checkout has non-ignored changes" >&2
  exit 2
}
submodule_status=$(git -C "$belyi_checkout" submodule status --recursive) || exit 2
if grep -Eq '^[-+U]' <<<"$submodule_status"; then
  echo "Belyi submodules are uninitialized or differ from recorded commits" >&2
  exit 2
fi

cext="$belyi_checkout/Cext"
source_file="$cext/powser_arnoldi.c"
makefile="$cext/Makefile"
[[ -f "$source_file" && -f "$makefile" ]] || {
  echo "pinned Cext sources are missing" >&2
  exit 2
}
source_sha256=$(sha256sum "$source_file" | awk '{print $1}')
makefile_sha256=$(sha256sum "$makefile" | awk '{print $1}')
[[ "$source_sha256" == "$pinned_source_sha256" ]] || {
  echo "powser_arnoldi.c hash mismatch" >&2
  exit 2
}
[[ "$makefile_sha256" == "$pinned_makefile_sha256" ]] || {
  echo "Cext Makefile hash mismatch" >&2
  exit 2
}

mkdir "$output_dir" || exit 2
printf '%s\n' "$submodule_status" >"$output_dir/belyi-submodules.txt"
start=$SECONDS
fixed_cflags='-O2 -pthread -Wl,-z,noexecstack'
if [[ -n "$dependency_prefix" ]]; then
  build_target=server
  for library in libflint.a libmpfr.a libgmp.a; do
    [[ -f "$dependency_prefix/lib/$library" ]] || {
      echo "dependency library not found: $dependency_prefix/lib/$library" >&2
      exit 2
    }
  done
  make -B -C "$cext" server PREFIX="$dependency_prefix" CFLAGS="$fixed_cflags" \
    >"$output_dir/build.log" 2>&1
else
  build_target=powser_arnoldi
  make -B -C "$cext" powser_arnoldi CFLAGS="$fixed_cflags" \
    >"$output_dir/build.log" 2>&1
fi
build_exit_code=$?
binary="$cext/powser_arnoldi"
selftest_exit_code=not_run
selftest_marker_count=0
if [[ $build_exit_code -eq 0 && -x "$binary" ]]; then
  "$binary" --selftest >"$output_dir/selftest.log" 2>&1
  selftest_exit_code=$?
  selftest_marker_count=$(grep -c '^SELFTEST PASSED$' \
    "$output_dir/selftest.log" || true)
fi

binary_sha256=not_built
[[ -x "$binary" ]] && binary_sha256=$(sha256sum "$binary" | awk '{print $1}')
gnu_stack=not_built
[[ -x "$binary" ]] && gnu_stack=$(readelf -W -l "$binary" | \
  awk '$1 == "GNU_STACK" {print $7}')
dependency_library_hashes=system
if [[ -n "$dependency_prefix" ]]; then
  dependency_library_hashes=$(sha256sum \
    "$dependency_prefix/lib/libflint.a" "$dependency_prefix/lib/libmpfr.a" \
    "$dependency_prefix/lib/libgmp.a" | sha256sum | awk '{print $1}')
fi
{
  printf 'key\tvalue\n'
  printf 'project_revision\t%s\n' "$(git -C "$project_root" rev-parse HEAD)"
  printf 'project_dirty\t%s\n' \
    "$([[ -n $(git -C "$project_root" status --porcelain) ]] && echo true || echo false)"
  printf 'runner_sha256\t%s\n' \
    "$(sha256sum "$script_dir/check-belyi-carnoldi.sh" | awk '{print $1}')"
  printf 'belyi_revision\t%s\n' "$actual_revision"
  printf 'belyi_dirty\tfalse\n'
  printf 'belyi_submodules_sha256\t%s\n' \
    "$(sha256sum "$output_dir/belyi-submodules.txt" | awk '{print $1}')"
  printf 'powser_source_sha256\t%s\n' "$source_sha256"
  printf 'makefile_sha256\t%s\n' "$makefile_sha256"
  printf 'compiler\t%s\n' "$(command -v gcc)"
  printf 'compiler_version\t%s\n' "$(gcc --version | head -n 1)"
  printf 'build_target\t%s\n' "$build_target"
  printf 'cflags\t%s\n' "$fixed_cflags"
  printf 'dependency_prefix\t%s\n' "${dependency_prefix:-system}"
  printf 'dependency_library_hashes_sha256\t%s\n' "$dependency_library_hashes"
  printf 'binary_sha256\t%s\n' "$binary_sha256"
  printf 'gnu_stack_flags\t%s\n' "$gnu_stack"
} >"$output_dir/config.tsv"

outcome=failed
runner_exit_code=1
if [[ $build_exit_code -eq 0 && $selftest_exit_code == 0 &&
      $selftest_marker_count -eq 1 && "$gnu_stack" != *E* ]]; then
  outcome=selftest_passed
  runner_exit_code=0
fi
{
  printf 'key\tvalue\n'
  printf 'outcome\t%s\n' "$outcome"
  printf 'build_exit_code\t%s\n' "$build_exit_code"
  printf 'selftest_exit_code\t%s\n' "$selftest_exit_code"
  printf 'selftest_marker_count\t%s\n' "$selftest_marker_count"
  printf 'wall_seconds\t%s\n' "$((SECONDS-start))"
  printf 'runner_exit_code\t%s\n' "$runner_exit_code"
} >"$output_dir/status.tsv"

printf '%s\n' "$outcome"
exit "$runner_exit_code"
