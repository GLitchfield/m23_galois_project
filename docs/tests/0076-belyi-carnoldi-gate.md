# Test 0076: pinned Belyi CArnoldi build and self-test gate

## Question

Can the optional C/FLINT Arnoldi stage in the pinned public Belyi package be
built and independently self-tested on this host without Magma or administrator
access?

## Method

The external package was checked out at Belyi revision
`f6f78dc2950343fcd9894c334f9a58f3ab065843`, with its recorded submodule state.
The project gate verifies that revision, rejects non-ignored changes and
submodule drift, and pins these package files by SHA-256:

- `Cext/powser_arnoldi.c`:
  `f304ff6a2e93f7c1ea31f69082623167ccdc70b9f8564eed1588932ec63d5a5b`;
- `Cext/Makefile`:
  `81af12b542ad88a8b5ab1bb9f9131787362e9d16f32280a8b779d59e72cb4bf9`.

Because system FLINT development headers were unavailable and `sudo` was not
usable noninteractively, the package's no-admin dependency script built GMP
6.3.0, MPFR 4.2.1, and FLINT 3.1.2 under `/tmp`. GNU m4 1.4.19 was first built
in the same prefix because the host lacked `m4`. The downloaded archive hashes
observed for this run were:

| archive | SHA-256 |
| --- | --- |
| `gmp-6.3.0.tar.xz` | `a3c2b80201b89e68616f4ad30bc66aee4927c3ce50e33929ca819d5c43538898` |
| `mpfr-4.2.1.tar.xz` | `277807353a6726978996945af13e52829e3abd7a9a5b7fb2793894e18f1fcbb2` |
| `flint-3.1.2.tar.gz` | `fdb3a431a37464834acff3bdc145f4fe8d0f951dd5327c4c6f93f4cbac5c2700` |
| `m4-1.4.19.tar.xz` | `63aede5c6d33b6d9b13511cd0be2cac046f2e70fd0a07aa9573a04a82783af96` |

These hashes record the bytes used; they do not replace upstream signature
verification. The package dependency script also does not run each
dependency's full test suite. The target helper's own self-test is the gate
used here.

The first static link inherited an executable-stack warning from a FLINT
assembly object. The project runner therefore supplies
`-Wl,-z,noexecstack`, records the resulting ELF `GNU_STACK` flags, and refuses
to pass a binary whose stack flags contain `E`.

## Result

Passed from clean project revision
`daf4d482c57b8ddaeb85e5790f95eab5891770e7` using GCC 13.3.0. The aggregate
hash of the three static library hashes was
`d56d7d593f35d3df2ebce854ff4d484ef54b9666047ea88b69461769e55f0625`.
The binary had SHA-256
`cb54f889a5ac4a479414cd49cc546352694be31a27491464e4dcee43f683ad88`
and ELF stack flags `RW`.

The package self-test found one kernel vector in each of its two Arnoldi
fixtures, reported reconstruction errors below `9e-72`, passed its independent
SVD residual check, and ended with exactly one `SELFTEST PASSED` marker. The
runner recorded build exit 0, self-test exit 0, and outcome `selftest_passed`.

This validates the standalone compiled helper and our build/provenance seam.
It does not load Magma, show that Magma's `PowerSeriesBasis` exchange protocol
reaches this binary, compute a target Belyi map, or validate the package
author's performance comparison. The bounded target run remains the
integration test.

## Reproduction

With either system FLINT 3 development packages or a local dependency prefix:

```sh
make check-belyi-carnoldi \
  BELYI_CHECKOUT=/path/to/Belyi \
  OUTPUT_DIR=/new/path/for/carnoldi-gate \
  DEPENDENCY_PREFIX=/path/to/local/prefix
```

The new output directory records submodules, build and self-test transcripts,
configuration hashes, and separate exit codes. It is an operational artifact
and is not committed.

## Evidence

- `scripts/check-belyi-carnoldi.sh`;
- the pinned external Belyi `Cext` source and Makefile; and
- the project regression's shell syntax check.
