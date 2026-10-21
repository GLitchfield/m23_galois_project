# Test 0107: König high-order mod-19 Newton lift

## Question

Can the order-by-order formal branch from Test 0106 be replaced by a
high-order exact lift suitable for recovering rational functions on the plane
curve?

## Implementation

The implementation revision is
`f594db70729704497b4f250092ff73c53a4383fc`. The authenticated input archive
has SHA-256
`62ce6415db167aeeb816d71fba83fc33b8637515d6c66673105c12b49d07dd44`.

Run:

```sh
make check-koenig-f19-newton \
    KOENIG_ARCHIVE=/path/to/archive.zip
```

`scripts/lift_koenig_f19_newton.sage` works over the truncated polynomial
ring `F_19[s]/(s^N)`, with `s=lambda-9`. It keeps the 46 moving normalized
coefficients and the inverse of the exact `46 x 46` Jacobian minor from Test
0106.

If `z` and `B` are correct modulo `s^n`, one doubling round computes

```text
z' = z - B F(z)                         mod s^(2n),
B' = B + B (I - J(z') B)                mod s^(2n).
```

Every round independently asserts

```text
F(z') = 0,
J(z') B' = I
```

at the new precision. Thus the implementation checks both the formal family
and its Newton inverse rather than trusting convergence.

## Exact result

Starting from the published mod-19 anchor, twelve doubling rounds reach
precision

```text
N = 4096.
```

All 46 normalized coefficient series have 4,096 exact coefficients; adjoining
`lambda=9+s` gives 47 series. The canonical serialization

```text
label<TAB>coefficient_0,...,coefficient_4095<NEWLINE>
```

has SHA-256

```text
456edbd96ee27eb5c99fdb2d5919d278fabfc3a1b96948900317daca2ea23802.
```

The compact committed summary is
`data/derived/m23_koenig_f19_newton_summary.tsv`. It records the code
revision, archive hash, SageMath version, precision, series digest, and the
first and last 16 coefficients of both `alpha` and `beta`. The full
approximately half-million-coefficient checkpoint is deliberately
regenerated rather than committed.

At precision 4,096 the verifier re-evaluates:

1. all 46 nontrivial universal-family coefficient identities;
2. the exact inverse-Jacobian identity; and
3. all 4,948 nonzero terms of the authenticated bidegree-`(97,98)` plane
   equation.

Both universal-family and plane-equation residuals are exactly zero modulo
`s^4096`. On the reference host the complete replay, including the plane
evaluation, takes about 40 seconds; elapsed time is operational and is not
part of the certificate.

## Consequence and next gate

The mod-19 moving family is now available at useful precision without König's
unreleased lift files. The next step is exact Padé/linear-algebra recovery of
relations

```text
P(alpha,beta) - c Q(alpha,beta) = 0
```

for `c=a,C` and the thirteen remaining coefficients of
`f1,f2,g1,g2`. Candidate relations must be validated on unused higher-order
terms and then checked exactly in
`Frac(F_19[alpha,beta]/(h mod 19))`. If the relation bases approach the full
plane-curve dimension, the same Newton implementation can be extended to
16,384 or 32,768 terms without changing the mathematical model.
