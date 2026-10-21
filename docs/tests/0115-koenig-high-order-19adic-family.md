# Test 0115: König high-order characteristic-zero local family

## Question

Can the exact mixed local family of Test 0114 be scaled to the formal
precision that was required to reconstruct the mod-19 coefficient map?

## Two-axis Hensel algorithm

A direct matrix Newton iteration over
`(Z/19^32 Z)[s]/(s^16384)` would perform expensive polynomial matrix
inversions with 135-bit coefficients. Instead the implementation separates
the two complete local directions.

First, inverse-Jacobian Newton doubling constructs the family and its full
46-by-46 inverse Jacobian over `F_19[[s]]/(s^16384)`. Then, if `x_k` solves
the equations modulo `19^k`, the exact residual is divided by `19^k` and the
fixed formal inverse Jacobian determines the next base-19 digit. This is
repeated through `k=32`.

The constant terms independently agree with the fixed 19-adic anchor from
Test 0113. At the end, all 46 cover equations are re-evaluated over the full
mixed ring.

## Result

The committed run reaches

```text
(Z/19^32 Z)[s]/(s^16384).
```

It certifies 753,664 coefficient residues. The authenticated
bidegree-`(97,98)` plane equation satisfies

```text
h(alpha(s),beta(s)) = 0 mod (19^32,s^16384),
```

and reduction of the entire family modulo 19 agrees with the independently
computed formal family from Test 0107. The canonical coefficient digest is

```text
b36d782e62901079e676ecfc70aee35693d3bd8cd634cc6454b9215c7475b039.
```

On the reference host the full run took 10 minutes 8 seconds and peaked at
2.0 GB RSS. These timings are operational observations, not mathematical
claims.

## Reconstruction gate

The local data now match the 16,384-term precision used in Tests 0108--0109,
with 32 p-adic digits available for rational reconstruction. The remaining
bottleneck is structured linear algebra, not lifting.

The mod-19 expression for `a=lambda^2` uses 5,252 numerator and 5,322
denominator terms, and the common family denominator uses 5,323 terms.
Blindly repeating dense elimination once per p-adic digit would waste the
known mod-19 relation space. The next calculation should instead Hensel-lift
that relation space with a fixed normalization and reusable mod-19 solve,
then:

1. rationally reconstruct its coefficients;
2. verify the resulting formulas globally modulo König's
   characteristic-zero plane equation; and
3. prove that at least one coefficient function is nonconstant.

This test does not itself supply those global formulas or settle the
`M23/A23` monodromy dichotomy.

## Evidence and replay

Implementation revision:
`b47dc310fe421dc29721183b2c8e2d5a47b66ce3`.

Compact certificate:

```text
1f9a294e7d5bdcc7f0089dd9a699949ba9e88795e34c1598063f2cffcee412f8
  data/derived/m23_koenig_19adic_family_16384.tsv
```

Replay against the authenticated archive:

```sh
make check-koenig-19adic-highorder \
    KOENIG_ARCHIVE=/path/to/Polynomials_And_Approximation_Data.zip
```
