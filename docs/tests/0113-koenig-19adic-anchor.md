# Test 0113: König characteristic-zero 19-adic anchor

## Question

Does the exact mod-19 anchor lift coherently to characteristic zero on both
the normalized universal-cover equations and König's plane curve?

## Characteristic-zero equations

Tests 0105--0112 worked modulo 19, where `1/4=5`. For a genuine 19-adic lift
the two normalized factor identities must instead use the rational constant
`1/4`:

```text
C(F3-F1) + (1/4+lambda)D = 0,
C(F5-F1) - (lambda-1/4)D = 0,
```

with

```text
F1=f1^3 f2,  F3=f3^2 f4,  F5=f5^2 f6,  D=g1^5 g2.
```

Fixing `lambda=9` leaves 46 normalized coefficients and 46 non-tautological
coefficient equations. Their Jacobian at the published mod-19 anchor has
determinant

```text
2 mod 19,
```

so it is a unit. Multivariate Hensel's lemma therefore gives a unique
`Z_19`-point lifting this normalized anchor.

## Exact digit lift

The implementation lifts one base-19 digit at a time. At precision `19^k`,
it divides the exact residual by `19^k`, solves the fixed 46-by-46 Jacobian
system over `F_19`, applies the correction, and re-evaluates every equation
modulo `19^(k+1)`.

The committed run reaches

```text
19^32 = 83198449060887472631428936505541918917761.
```

All 46 universal-cover equations vanish exactly modulo this modulus. The
authenticated characteristic-zero bidegree-`(97,98)` equation independently
also satisfies

```text
h(alpha,beta) = 0 mod 19^32
```

at the lifted coefficient pair. Its residues begin with the expected anchor
`(alpha,beta)=(7,14) mod 19`.

The SHA-256 digest of the canonical list of all 46 lifted coefficient
residues is

```text
43fb0eb2512560d1f2fa8cf710562a2ec986d6faa7efdf9990ecd2316b69474b.
```

This is the first exact bridge from the finite-characteristic reconstruction
to a characteristic-zero local point. It is not a rational point over `Q`,
does not yet provide coefficient functions on the full plane curve, and does
not resolve the `M23/A23` monodromy dichotomy.

## Next reconstruction seam

The next calculation should combine the two established lifts:

1. retain base-19 precision, as in this test;
2. let `lambda=9+s`, as in Tests 0106 and 0107;
3. Newton-lift the 46 coefficients in
   `(Z/19^N Z)[[s]]/(s^M)`; and
4. use those mixed-precision series to reconstruct and verify
   characteristic-zero rational coefficient functions.

That mixed lift supplies data for the exact tautological-family certificate
required by Test 0104. A single fixed 19-adic point cannot do so.

## Evidence and replay

Implementation revision:
`ea1a56f0ba64fe40828108fec53443973b063e2a`.

Compact certificate:

```text
15f4ef42b7786495a80add22c149ebd076335df3a21bc895577bd03664dfd536
  data/derived/m23_koenig_19adic_anchor.tsv
```

Replay against the authenticated archive:

```sh
make check-koenig-19adic \
    KOENIG_ARCHIVE=/path/to/Polynomials_And_Approximation_Data.zip
```
