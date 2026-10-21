# Test 0077: all-class 8A Belyi seed-conditioning census

## Correction

Test 0087 found that the Python residual helper used the exponent placement
for normalization `(4,2,1)` in every advertised chart. The implementation and
both ledgers have been corrected. The historical ranking below is superseded:
class 22 is not established as the strongest balanced follow-up. In the
corrected census, class 6, normalization `(1,4,2)`, has the smallest Tutte
residual, `0.0163974`, but its condition estimate is `4.19e18`, so it is not
promoted as a robust seed. See test 0087 for the corrected interpretation.

## Question

Can the cheap dessin-seed diagnostics be applied uniformly to all 28 certified
`(8A,8A,2A)` classes, and do they identify a better-prioritized follow-up than
continuing only with class 1?

## Method

For each class, the census constructs the exact 140-vertex, 414-edge,
276-triangle flag mesh in all three cyclic branch rotations. It uses the
lexicographically first outer flag triangle for a deterministic Tutte embedding
and evaluates all six permutations of the distinguished multiplicities
`(4,2,1)`: 18 seeds per class and 504 in total.

No Newton or continuation step is taken. Each seed is assessed by relative
coefficient residual, a row- and column-equilibrated Jacobian condition
estimate, and normalized minimum separation across all root collisions
represented by the five saturation gates (including a bounded nonzero-alpha
margin).

The selected chart in each row is the one with minimum relative residual.
Separate columns give the best condition estimate and largest separation seen
anywhere in the class; they need not occur in that selected chart. This avoids
pretending that the three diagnostics define a canonical scalar score.

The aggregate and 504-row TSVs record the generating revision, source SHA-256,
Python and NumPy versions, sampling rule, metrics, and exact complex-conjugate
class ID. The checker validates all 28 IDs, the conjugate mapping, sample and
mesh counts, finite positive metrics, orderings, and source hash. It also
independently reconstructs every aggregate selection, minimum, maximum, and
median from the 504 chart rows.

## Historical result (superseded by test 0087)

The initial aggregate passed at revision
`daf4d482c57b8ddaeb85e5790f95eab5891770e7`. The aggregate and detailed ledger
were regenerated together at revision
`9adfe97a5578de43fbfc2f64a837aa5f3fd56253`, with Python 3.12.3 and NumPy
2.4.3. The initial full run took 5.52 seconds and 39,352 KB maximum RSS on this
host; these are operational observations, not performance claims.

The lowest initial residuals were:

| class | minimum relative residual |
| ---: | ---: |
| 22 | `0.0293263` |
| 21 | `0.0343977` |
| 26 | `0.0421046` |
| 27 | `0.0732963` |
| 1 | `0.124757` |

Class 22 also had the third-lowest median residual, the sixth-best minimum
condition estimate (`2.5125e7`), and the third-largest maximum normalized root
separation (`0.00325149`). It is therefore the strongest balanced class-level
follow-up in this deliberately limited census. Its minimum-residual chart is
rotation 1 with normalization `(1,2,4)`.

The warning is important: that selected chart's equilibrated Jacobian condition
estimate is about `2.69e17`. The best condition and separation for class 22
occur in other charts. No row is a Belyi map, and the diagnostics do not
demonstrate a basin of attraction. Complex-conjugate pairs can also have very
different values because the canonical outer triangle is
representative-dependent; the census is not a Galois invariant.

The class-22 follow-up also exposed a scale bug in the older continuation
preflight. Its separated seed has a raw 15-root Vandermonde product near
`2.76e-58`; the previous absolute `1e-14` cutoff therefore called it singular
despite normalized root separation `0.00164586`. Since the augmented equations
divide each gate by its seed value, that cutoff was chart- and degree-dependent.
The preflight now rejects only zero or nonfinite seed gates, with regression
coverage for tiny nonzero values. This lets the conditioning of the actual
augmented Jacobian decide whether tracking can proceed.

## Historical consequence (withdrawn)

The original run treated class 22 as a rational choice for a bounded numerical
experiment. That prioritization is withdrawn. The circle-packing pilot still
accepts class, cyclic rotation, and normalization, and the Magma bundle still
accepts `M23_BELYI_CLASS_ID` from 1 through 28.

The ranking is only weakly connected to the specialized Magma solver: Magma
builds its own uniformization rather than consuming these Tutte seeds. A
class-22 Magma success would be meaningful; a failure would not validate or
invalidate the census. Exact ramification and cover monodromy remain mandatory
after any numerical success.

## Reproduction

```sh
make check-8a-conditioning-census
make reproduce-8a-conditioning-census
```

The second command regenerates the floating-point artifact and updates its
software versions and Git revision. Cross-platform last-bit equality is not
asserted; the structural checker enforces the evidence contract independently.

## Evidence

- `data/derived/m23_8a_belyi_conditioning_census.tsv`;
- `data/derived/m23_8a_belyi_conditioning_seeds.tsv`;
- `scripts/census_8a_belyi_conditioning.py`;
- `scripts/check_8a_belyi_conditioning_census.py`;
- `scripts/test_census_8a_belyi_conditioning.py`; and
- `data/derived/m23_8a_8a_2a_inner_classes.tsv`.
