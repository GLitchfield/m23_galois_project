# Test 0039: exact CUDA permutation batch and CPU coexistence

## Question

Can the RTX 4080 compute the two regular pure-braid images used by the native
quotient kernel exactly, at useful transfer-inclusive throughput, while a real
native 5A ledger batch and the active 4A production workers continue on CPU?

## Inputs and provenance

- implementation: the commit containing this note;
- fixture: `data/reference/native_kernel_fixture.tsv`, generated independently
  by GAP and containing both general and 4A tuples;
- NVIDIA GeForce RTX 4080, 16,376 MiB, compute capability 8.9;
- NVIDIA driver 591.59 and user-local CUDA 12.0.140 compiler/runtime;
- user-local GCC 12.4 host compiler, because CUDA 12.0 does not parse the
  system GCC 13/libstdc++ headers;
- packed tuple size: 92 bytes (four degree-23 permutations);
- benchmark batch: 1,000,000 tuples, producing two edge attempts per tuple.

The operational outputs remain under `runs/` and are not committed. With a
compatible CUDA toolchain, reproduce the exact microbenchmark with:

```bash
scripts/benchmark-cuda-permutation-batch.sh 1000000
```

Set `M23_NVCC`, `M23_CUDA_ROOT`, and `M23_CUDA_HOST_CXX` when the toolchain is
not installed system-wide. `M23_CUDA_REPEATS` reuses the allocated batch for a
longer coexistence run.

## Exact result

The host implementation first reproduces GAP's beta13 and beta14 fixtures for
both input tuples. The CUDA batch alternates those two inputs; the kernel agrees
bit-for-bit with the CPU for all 2,000,000 returned braid images. This is a
narrow exact fixture, not a diverse destination-key sample. A one-repeat run
measured:

- CPU single core: 13.47 million edge attempts/second;
- GPU kernel: 249.59 million edge attempts/second;
- GPU including host-to-device input and both device-to-host outputs: 47.84
  million edge attempts/second.

Allocation took 250 ms and is reported separately because a production engine
would retain device buffers. The transfer-inclusive figure does not hide
allocation inside the kernel rate.

## Coexistence result

A 500-repeat CUDA run processed one billion edge attempts while the active 4A
GAP pipeline and a 20-block native 5A ledger batch ran concurrently. It
retained exact CPU/GPU agreement and measured 247.29 million kernel edge
attempts/second and 46.85 million transfer-inclusive attempts/second. The
native ledger batch completed in 16.873 seconds at 1.185 blocks/second, versus
20.042 seconds and 0.998 blocks/second in the earlier GPU-free observation.
The apparent 18.7 percent CPU improvement is benchmark noise/cache variation,
not a claimed speedup; importantly, there was no observed CPU slowdown in this
sample.

## Limits and verdict

Passed the exact arithmetic, batching, transfer-inclusive throughput, and
coexistence gates. This is not yet an end-to-end GPU search: destination-key
construction, sorting/deduplication, component unions, and certified ledger
integration remain on the critical path. The result supports continuing with
that bulk graph prototype because the GPU supplies useful additive regular
work without displacing the CPU pipeline.
