# Test 0145: König F19 solver positive control

## Question

Can the exact finite-field solver proposed after Test 0144 recover König's
already known normalized cover over `F_19` within a predeclared resource
envelope?

## Result

No. This is a positive control, so nonexistence is not a possible
explanation: exact substitution verifies that König's known cover at

```text
(p, alpha, beta, lambda) = (19, 7, 14, 9)
```

satisfies every equation in each tested presentation.

The selected presentation scales the two simple order-two factors, puts their
coefficients first in the variable order, and hides all remaining known
coefficients from the solver. It has 44 variables, 46 equations, 2,042 terms,
and maximum degree 6. Its canonical input SHA-256 is

```text
e7d00cb330e140f57a987570cc396477a41b0d0317de8254858c96d1e5c5f3c9
```

The deterministic `msolve 0.10.1` run used four threads, random seed 1, at
most 2,048 pairs per matrix, an 8,388,608 KiB virtual-memory limit, and a
7,200-second wall limit. It returned no output and ended before the wall limit
with status 139 while working at F4 degree 7. The largest observed matrix had
1,424,587 rows and 5,473,575 columns, the pair frontier reached 141,284, and
peak resident memory was 7,372,096 KiB.

The raw wrapper classification is `failed`. Status 139 is consistent with
signal 11 near the declared virtual-memory ceiling, but this certificate does
not infer a unique operating-system cause from the exit status.

## Factor-aware alternatives

Two exact eliminations were also constructed and checked against the known
solution:

| Presentation | Variables | Equations | Terms | Maximum degree |
| --- | ---: | ---: | ---: | ---: |
| scaled, simple variables first | 44 | 46 | 2,042 | 6 |
| remainder modulo squared factors | 30 | 32 | 24,232 | 10 |
| polynomial/derivative remainders | 30 | 32 | 247,384 | 17 |

Eliminating the repeated factors reduces the variable count but greatly
increases term count and degree. Together with the failed positive control,
this closes the current generic Gröbner and direct factor-remainder route as a
credible mechanism for enumerating second-prime seeds. It does not rule out a
new specialized algorithm, a controlled deformation, or author-supplied
moving data.

## Provenance and replay

The solver input and run were produced at revision
`95703c05de05c7bd2154dfbbe613891d5c696400` with SageMath 10.9 and
`msolve 0.10.1`. The compact certificate records the exact presentation
statistics and hashes, the full declared limits, and the observed bounded-run
result. Large solver matrices, logs, and empty output remain machine-local.

```text
b32b28e5479356e5bacc7b56f39fe723efb1895cbebd6ce8ffe069b1603dd5cf
  data/derived/m23_koenig_f19_positive_control.tsv
```

Replay into a fresh directory:

```sh
./scripts/benchmark-koenig-f19-positive-control.sh \
  runs/koenig-f19-positive-control-replay 7200 4 8388608

./scripts/run-8a-sage.sh --python \
  scripts/audit_koenig_f19_positive_control.sage \
  --benchmark-summary \
    runs/koenig-f19-positive-control-replay/summary.tsv \
  --check-summary \
    data/derived/m23_koenig_f19_positive_control.tsv

make check-koenig-f19-positive-control
```

The replay requires the exact systems, known-solution checks, hashes, solver
version, and declared parameters to agree. It ignores the code revisions and
host-dependent exit status, output size, peak RSS, degree, matrix dimensions,
and pair frontier. The ordinary compact checker verifies the exact
measurements from the official run.

## Decision

The generic solver is closed for a second-prime anchor. This is the last test
of the König `(2A,2A,3A,5A)` characteristic-zero reconstruction; the route
stops here without a characteristic-zero family.
