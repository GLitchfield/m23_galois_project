# Test 0150: König M24 genus-11 `(-2,0)` cluster resolution

## Question

Do the 4,356 terminal boxes modulo `2^18` from Test 0149 converge to a
manageable set of exact critical points, and do any branches above those
points belong to the normalization over `Q_2`?

## Exhaustive cluster partition

The audit reads all four content-bound Test 0149 checkpoints, verifies their
schema and provenance, merges all 580 base-box records, and reproduces the
4,356-box frontier digest

```text
a354bee670ec4936d552384a0bdb8f792c069faa1c8cbbf2c00929bde8ff506d
```

Exactly 4,352 boxes have chart residues `(t,x) = (1,63) mod 64`. The other
four have residues `(63,49) mod 64`:

```text
(2943,58993), (2943,190065),
(134015,124529), (134015,255601).
```

The two cluster digests and their union are checked independently.

## Dominant cluster at `(1,-1)`

In the integral `(-2,0)` chart, `(1,-1)` is an exact singular point. After
translation it has multiplicity 10 and tangent cone

```text
6718464 t^10.
```

Its minimum `(2,1)`-weighted order is 20. On writing `t=z x^2`, the
exceptional polynomial factors exactly as

```text
6718464 (z+1/2)^2 (z^2+4/3 z+1/9)^4.
```

The quadratic factor has discriminant `4/3`, a nonsquare in `Q_2`. The only
`Q_2`-rational exceptional direction is therefore `z=-1/2`. Following that
direction and dividing by `x^20` gives a strict transform of multiplicity two
with tangent cone

```text
29282 (2t^2 + 4tx + x^2).
```

Its discriminant is `8`, also nonsquare in `Q_2`. Thus no
`Q_2`-rational normalization branch lies above this singular point, excluding
all 4,352 boxes in the dominant cluster.

## Four-box exceptional cluster

The exact degree-442 singular factor `q_6` from the `(-6,0)` elimination of
Test 0149 also controls this cluster. The chart-coordinate relation is

```text
q_2(t) = monic(q_6(16t)).
```

At the two distinct terminal `t` centers, `(v_2(q_2),v_2(q_2'))` equals
`(63,46)` and `(66,46)`. Newton lifting from the latter gives

```text
(66,46), (86,46), (126,46), (206,46), ...
```

so the strong Hensel inequality holds after two iterations. The exact linear
subresultant witness from Test 0149 recovers the corresponding `x` coordinate.
In the `(-2,0)` chart, the negative Hessian determinant has square class

```text
valuation 53, odd unit 5 mod 8.
```

It is nonzero and nonsquare. This embedding is another ordinary double point
with no `Q_2`-rational normalization branch, excluding the last four boxes.

## Result and scope

All 4,356 boxes in the `(-2,0)` frontier are exactly excluded. Together with
Test 0149, both unit corridors left by Test 0147 are closed. This still does
not alone prove that the smooth projective curve has no `Q_2`-point: the
unbounded tropical valuation tails require a separate exhaustive argument.

## Provenance and replay

The compact certificate was generated with SageMath 10.9 from the
authenticated external OPUS archive and the ignored operational checkpoint
directory:

```sh
./scripts/run-8a-sage.sh --python \
  scripts/audit_m24_genus11_minus2_clusters.sage \
  /path/to/Polynomials_And_Approximation_Data.zip \
  --run-dir runs/m24-genus11-minus2-depth18-v3 \
  --check-summary \
    data/derived/m24_koenig_genus11_minus2_clusters.tsv

make check-m24-genus11-minus2-clusters
```

The degree-442 factor is recorded by a canonical digest because its exact
coefficients are large and are reproducibly recomputed from the authenticated
model. The operational checkpoints and external archive are not committed.
Certificate SHA-256:

```text
12a0a6548e3352b0ae4225c45b85a5e452f04a82eb3524d14696157b9d46e108
```

## Next gate

Replace the bounded tropical window by a finite central audit plus symbolic
ray certificates, including an effective weighted neighborhood of the
`(1/4,0)` boundary center.
