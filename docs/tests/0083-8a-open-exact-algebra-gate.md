# Test 0083: open exact-algebra gate for the 8A Belyi equations

## Question

Can Sage, Singular, and `msolve` provide a reproducible local replacement for
the exact-algebra portions of the unavailable Magma workflow, and which
equation presentation should be used first?

## Method

The repository now pins Sage 10.9 through conda-forge and the official static
`msolve` 0.10.1 Linux x86-64 binary by version and SHA-256. The generated
normalized system has equivalent Sage and Magma source presentations. A Sage
exporter maps either presentation to `F_13` in `msolve` syntax.

One benchmark at committed revision
`cf3d5f2ed4ceade72cae446454366926e01d060e` gave Singular and `msolve` separate
60-second wall limits. `msolve` used eight requested threads, deterministic
random seed 1, degree-reverse-lexicographic order, and its default exact sparse
linear algebra. The inputs and detailed logs remain machine-local under
`runs/8a-exact-algebra-p13-full-cf3d5f2/`; the compact summary records versions,
input hashes, structural counts, exit status, and maximum resident memory.

## Result

The presentation comparison reverses the naive variable-count preference:

| presentation | variables | equations | terms | bytes |
| --- | ---: | ---: | ---: | ---: |
| full coefficient identity | 23 | 23 | 1,843 | 31,746 |
| repeated-root remainders | 16 | 16 | 404,461 | 10,091,932 |

The 16-variable remainder computation expands the equations by more than a
factor of 200. The sparse 23-variable presentation is therefore the correct
first exact-algebra input.

Neither engine completed a Groebner basis in 60 seconds. `msolve` completed F4
rounds through degree 11, began degree 12, and reached 1,681,772 KiB maximum
RSS before the hard timeout. Singular constructed the same system but did not
return a basis within its limit. These are bounded engineering measurements,
not evidence that the ideal has no solutions.

The tools close useful portions of the Magma gap—portable equation export,
finite-field exact algebra, and later exact recognition—but this unsaturated
global ideal is not a cheap seed generator. The next primary seed effort is
the Barth--Wenz conformal-welding construction. Further exact-algebra work
should be tied to a concrete specialization, saturation, or numerical seed,
not an unbounded global Groebner run.

## Reproduction

```sh
./scripts/setup-8a-sage.sh
./scripts/setup-msolve.sh
make check-8a-exact-algebra
./scripts/benchmark-8a-exact-algebra.sh 13 full 60 8
```

The benchmark writes only to `runs/`. Regenerating the exact resource numbers
on different hardware is not expected; input hashes and qualitative
completion/timeout states are the portable comparison.

## Evidence

- `data/derived/m23_8a_exact_algebra_benchmark.tsv`;
- `scripts/export_8a_belyi_msolve.sage`;
- `scripts/benchmark_8a_singular.sage`;
- `scripts/benchmark-8a-exact-algebra.sh`;
- `scripts/check-8a-exact-algebra.sh`; and
- `sage/8a_belyi/`.
