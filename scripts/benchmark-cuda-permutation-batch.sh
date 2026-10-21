#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "usage: $0 BATCH_SIZE [FIXTURE]" >&2
  echo "set M23_CUDA_REPEATS to reuse the allocated batch" >&2
  exit 2
fi

fixture=${2:-data/reference/native_kernel_fixture.tsv}
fixture=$(realpath "$fixture")
nvcc=${M23_NVCC:-}
cuda_root=${M23_CUDA_ROOT:-}
if [[ -z "$nvcc" && -x /tmp/m23-cuda-local/root/usr/lib/nvidia-cuda-toolkit/bin/nvcc ]]; then
  cuda_root=/tmp/m23-cuda-local/root/usr
  nvcc=$cuda_root/lib/nvidia-cuda-toolkit/bin/nvcc
elif [[ -z "$nvcc" ]]; then
  nvcc=$(command -v nvcc || true)
fi
[[ -n "$nvcc" && -x "$nvcc" ]] || {
  echo "CUDA compiler unavailable; set M23_NVCC and M23_CUDA_ROOT" >&2
  exit 69
}
if [[ -z "$cuda_root" ]]; then
  cuda_root=${CUDA_HOME:-/usr}
fi
host_cxx=${M23_CUDA_HOST_CXX:-}
if [[ -z "$host_cxx" && -x /tmp/m23-cuda-local/gcc12/usr/bin/g++-12 ]]; then
  host_cxx=/tmp/m23-cuda-local/gcc12/usr/bin/g++-12
elif [[ -z "$host_cxx" ]]; then
  host_cxx=$(command -v g++-12 || command -v g++)
fi

binary=$(mktemp)
trap 'rm -f "$binary"' EXIT
export PATH="$cuda_root/bin:$cuda_root/lib/nvidia-cuda-toolkit/bin:$PATH"
"$nvcc" -std=c++17 -O3 -arch=sm_89 -allow-unsupported-compiler \
  -ccbin "$host_cxx" -I"$cuda_root/include" \
  src/cuda/m23_permutation_batch.cu -o "$binary" \
  -L"$cuda_root/lib/x86_64-linux-gnu" -L/usr/lib/wsl/lib \
  -Xlinker -rpath -Xlinker "$cuda_root/lib/x86_64-linux-gnu"
LD_LIBRARY_PATH="$cuda_root/lib/x86_64-linux-gnu:/usr/lib/wsl/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
  "$binary" "$fixture" "$1" "${M23_CUDA_REPEATS:-1}"
