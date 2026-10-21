# Test 0144: König second-prime feasibility audit

## Question

Do the currently available exact and numerical mechanisms provide a
certified normalized-cover anchor at a second good prime, authorizing a
high-order lift and multi-prime CRT reconstruction?

## Result

Not yet. Exact reduction of König's authenticated plane equation finds many
smooth affine points outside the reductions of the five reported boundary
points:

| Prime | Affine | Smooth | Smooth reported-point reductions | Smooth other | Selected |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 11 | 19 | 13 | 3 | 10 | `(0,6)` |
| 13 | 28 | 23 | 3 | 20 | `(0,0)` |
| 17 | 32 | 24 | 3 | 21 | `(0,5)` |

Here "reported-point reductions" refers only to the five rational points
listed in the dissertation. The complete degeneration divisor is not
certified, so the other points must not yet be called nonboundary points.
This clears the smooth-plane-point gate but does not itself lift any point to
the normalized universal-cover equations or certify that it is interior.

At the selected `F_11` point `(alpha,beta)=(0,6)`, fixing the normalized
branch label to `lambda=1` and absorbing the common constant into the two
simple order-two factors gives a sparse system with:

```text
variables       44
equations       46
terms         1930
maximum degree   6
input SHA-256  a1585a1409aa315c1c226102b74f1d1d449b41cf323f57a309f73ff06a1a360e
```

A deterministic four-thread `msolve 0.10.1` run with random seed 1 reaches
degree 6 and an observed matrix of 328,997 rows by 1,631,261 columns before
the declared 120-second timeout. Peak resident memory was 2,784,660 KiB.
No solver output was produced. This rejects the current monolithic Gröbner
presentation as a cheap seed mechanism at this one point and branch label; it
does not prove that the system has no solution, nor does it exclude another
point, label, or second prime.

## Independent numerical-fiber gate

The official archive supplies 980 approximately 200-decimal-digit complex
cover vectors over the single branch fiber `a=1/4`, not moving finite-field
data. The audit parses the 980 alpha coordinates at 700-bit precision and
forms the degree-980 polynomial after each Möbius change

```text
z = 1 / (alpha - c),  c in {4,5,6,8,10}.
```

Each chart is normalized by its largest coefficient. Rational reconstruction
uses denominator bound `10^80` and accepts a coefficient only below relative
error `10^-160`. The base chart at center 4 accepts 686 coefficients and
leaves 295 unknowns. The other four charts accept 708, 721, 748, and 762
coefficients. Including one scale per target chart yields 2,939 exact rational
constraints in 299 columns.

The constraint matrix has full column rank 299 modulo 1,000,003. Solving an
independent square subsystem modulo 1,000,000,009 leaves exactly 607 nonzero
residuals in the complete constraint set. Thus the reconstructed rational
coefficients are mutually inconsistent across charts. The released numerical
fiber cannot be promoted to an exact alpha-fiber polynomial under this
predeclared gate.

This second failure is independent of the finite-field Gröbner timeout. It
does not show that the exact alpha fiber is irrational; it shows that the
available archive precision and current rational-reconstruction mechanism do
not certify it.

## Provenance and replay

The external input is the Würzburg OPUS
[polynomials and approximations archive](https://opus.bibliothek.uni-wuerzburg.de/opus4-wuerzburg/files/10014/Polynomials_And_Approximation_Data.zip),
kept outside the repository because of its copyright status.

```text
official archive SHA-256
62ce6415db167aeeb816d71fba83fc33b8637515d6c66673105c12b49d07dd44

tooling and benchmark revision
f3aca075db6c2c49d3c5153167f660fcf1759853

SageMath 10.9
msolve 0.10.1
```

From a checkout containing the committed certificate, create a fresh
machine-local benchmark directory and then regenerate it:

```sh
./scripts/benchmark-koenig-second-prime.sh \
  /path/to/Polynomials_And_Approximation_Data.zip \
  runs/koenig-second-prime-replay 120 4

./scripts/run-8a-sage.sh --python \
  scripts/audit_koenig_second_prime_feasibility.sage \
  /path/to/Polynomials_And_Approximation_Data.zip \
  --benchmark-summary runs/koenig-second-prime-replay/summary.tsv \
  --check-summary \
    data/derived/m23_koenig_second_prime_feasibility.tsv

make check-koenig-second-prime-feasibility
```

The replay requires all mathematical counts and the solver-input hash to
agree. It ignores the code revision and the benchmark exit status, outcome,
peak RSS, last degree, and matrix dimensions: those are observations from a
wall-clock-limited run and can vary with host speed. The ordinary checker
still verifies the exact measurements recorded for the committed official
run.

Committed compact certificate:

```text
e57e80afcfbb66ecb71a8e6c1f4198fb17b81419230d856d6a2c4a572796364b
  data/derived/m23_koenig_second_prime_feasibility.tsv
```

Machine-local solver input, output, timing data, and logs are intentionally
not committed.

## Outcome

No high-order second-prime lift or CRT reconstruction was run. Test 0145
applies the proposed exact solver to the known `F_19` cover as a positive
control. The solver returns no output before status 139 at F4 degree 7, while
direct factor-remainder eliminations increase degree and term count sharply.
This closes the current generic Gröbner/factor-remainder route.
