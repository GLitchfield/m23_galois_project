# Test 0114: König characteristic-zero 19-adic local family

## Question

Can the fixed characteristic-zero anchor of Test 0113 and the moving
mod-19 family of Tests 0106--0107 be combined into one exact local family?

## Mixed lift

Work in

```text
(Z/19^32 Z)[s]/(s^64),   lambda=9+s.
```

The constant term is the unique normalized anchor from Test 0113. Its
46-by-46 coefficient Jacobian has determinant `2 mod 19`, hence is invertible
over `Z/19^32 Z`. The formal implicit-function theorem therefore determines
each of the remaining 46 coefficient series uniquely.

The implementation solves one fixed Jacobian system for every new
coefficient of `s`. After each solve, it re-evaluates all 46
universal-cover equations through the newly reached precision. The committed
run determines 64 terms of every series and verifies all equations exactly
modulo `(19^32,s^64)`.

## Independent checks

Three checks address different failure modes:

1. the normalized factor identities use the characteristic-zero constant
   `1/4`, rather than its residue `5 mod 19`;
2. the authenticated bidegree-`(97,98)` plane equation satisfies
   `h(alpha(s),beta(s))=0` coefficient-by-coefficient through `s^63`; and
3. reducing all 2,944 lifted coefficient residues modulo 19 reproduces the
   independently implemented high-order `F_19[[s]]` lift exactly.

The canonical digest of those 2,944 mixed coefficients is

```text
8114415ba1d651040aa6da4e18c2e6b60e88ea16025db4afbf4c7c45eb9f73d5.
```

This is an exact characteristic-zero local coefficient map. It is not yet a
global rational-function formula on König's plane curve, a proof that the map
has degree one, or a resolution of the `M23/A23` monodromy dichotomy.

## Reconstruction consequence

The calculation removes the existence and compatibility risk from the
characteristic-zero reconstruction. The remaining issue is scale and linear
algebra: the mod-19 degree-105 recovery used more than 16,000 formal
coefficients, whereas this deliberately bounded certificate has 64.

Test 0115 completes this scale step with a two-axis Newton/Hensel algorithm
and 16,384 terms at 32 p-adic digits. The next step is now to lift the already
known mod-19 relation space and common denominator, rather than rediscovering
the full ansatz over characteristic zero.

## Evidence and replay

Implementation revision:
`e55eea3e1ac7029766304c54ddf590bf8d24fd2f`.

Compact certificate:

```text
3bf71856479f1fec8661f8f69f5ea2cfc44a3ada9d1d2b6f458049b0f3d06540
  data/derived/m23_koenig_19adic_family.tsv
```

Replay against the authenticated archive:

```sh
make check-koenig-19adic-family \
    KOENIG_ARCHIVE=/path/to/Polynomials_And_Approximation_Data.zip
```
