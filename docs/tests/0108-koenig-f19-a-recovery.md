# Test 0108: König mod-19 branch-parameter recovery

## Question

Can the first missing moving-family function, the branch parameter
`a=lambda^2`, be recovered as a rational function of König's plane
coordinates `(alpha,beta)` without the unreleased original lift files?

## Fixed recovery problem

The implementation revision is
`939066504cc90c3e298dd286f053685ea9a7a9b3`. The authenticated input archive
has SHA-256
`62ce6415db167aeeb816d71fba83fc33b8637515d6c66673105c12b49d07dd44`.

Test 0107's inverse-Jacobian Newton method is extended from 4,096 to 16,384
exact coefficients over `F_19`, with

```text
s = lambda - 9,
u = alpha - 7,
v = beta - 14,
a = lambda^2.
```

The recovery asks for

```text
P(u,v) - a Q(u,v) = 0
```

in the fixed ansatz

```text
0 <= deg_u(P) <= 96,
0 <= deg_v(P) <= 97,
total_degree(Q) <= 110.
```

The first 16,000 series coefficients build an exact
`16000 x 15722` matrix over `F_19`; the remaining 384 coefficients are held
out. This is a declared finite-dimensional recovery problem, not an
unrestricted claim that the resulting expression has globally minimal
degree.

The full high-memory replay is:

```sh
make reproduce-koenig-f19-a \
    KOENIG_ARCHIVE=/path/to/Polynomials_And_Approximation_Data.zip
```

The ordinary substitution check is:

```sh
make check-koenig-f19-a
```

The doubled-precision check, which takes about eleven minutes on the reference
host, is:

```sh
make check-koenig-f19-a-long
```

## Exact rank and cutoff result

The training matrix has rank 15,151 and right-kernel dimension 571. Every one
of those 571 kernel vectors also vanishes on the 384 held-out coefficients.
The projection of the validated kernel to the numerator coordinates has rank
480.

Imposing successive total-degree cutoffs on `Q` gives:

| cutoff | relation dimension | numerator rank |
| ---: | ---: | ---: |
| 98 | 1 | 0 |
| 99 | 3 | 0 |
| 100 | 6 | 0 |
| 101 | 10 | 0 |
| 102 | 15 | 0 |
| 103 | 21 | 0 |
| 104 | 28 | 0 |
| 105 | 86 | 50 |

Thus, within the fixed ansatz, degrees through 104 produce only relations
with zero numerator, coming from multiples of the plane equation. Degree 105
is the first cutoff with a genuine `P-aQ` relation.

The deterministic echelon choice yields primitive polynomials with:

```text
total_degree(P) = 105,  terms(P) = 5,252,
total_degree(Q) = 105,  terms(Q) = 5,322,
gcd(P,Q) = 1.
```

Their sparse exact serialization is
`data/derived/m23_koenig_f19_a_relation.tsv`, with SHA-256

```text
700f5f8ac1a1581bf163f8397f10ce1dfc0eae285b2c323736f58947d2ab5ad6.
```

## Independent doubled-precision validation

The verifier starts again from the published mod-19 anchor, without reusing
the recovery series or matrix, and lifts to 32,768 coefficients. Exact
substitution gives

```text
P(alpha-7,beta-14) - lambda^2 Q(alpha-7,beta-14)
    = 0 mod s^32768.
```

All 16,384 coefficients beyond the fitting precision are therefore new
validation data. The numerator and denominator both have local valuation 2.
Consequently the displayed quotient has a base point on the singular plane
model at `(7,14)`, although its quotient extends along the selected
normalization branch and has value `lambda^2=5` there. One must not evaluate
the sparse formula at the anchor as a naive `0/0` quotient.

The compact validation record is
`data/derived/m23_koenig_f19_a_validation.tsv`.

## Consequence and next gate

This is strong exact local evidence for the first moving-family function and
a complete reproducibility certificate for how the candidate was selected.
It is not yet a global identity in the plane function field: finite formal
agreement, however long, is not by itself that theorem.

Next recover `C` and the thirteen coefficients of `f1,f2,g1,g2`. Substitute
all recovered functions into the universal cover identities and reduce the
resulting rational-function numerators exactly modulo König's plane equation
over `F_19`. That global check will certify the tautological family and the
nonconstant component-to-plane map needed for the characteristic-zero genus
comparison.
