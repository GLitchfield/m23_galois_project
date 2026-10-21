# Test 0146: König M24 genus-11 model and 2-adic gate

## Question

Can König's primary characteristic-zero model for the
`(2A,2A,2B,8A)` M24 Hurwitz curve be authenticated, and does a bounded
affine-integral `Q_2` chart audit find either a simple local point or a finite
obstruction?

## Primary-source intake

The official Würzburg OPUS dissertation and artifact endpoints are accessible
again. The dissertation PDF has SHA-256

```text
f676b3f5d00a4d9960ea10e2032f86321741a201751c3e6b9d55f787c60a1618
```

Theorem 5.2 and Appendix 5.1.12 identify the exact plane equation. The audit
authenticates the official artifact archive and parses that equation directly:

```text
archive SHA-256
62ce6415db167aeeb816d71fba83fc33b8637515d6c66673105c12b49d07dd44

model-member SHA-256
8fc3f13944653c89e0de309632f5f11aaccd18aaed41cbf794db036fd57d31a2

terms          633
degree in t     32
degree in x     24
total degree    44
integer content  1
```

The dissertation proves that the curve is absolutely irreducible of genus 11.
This intake authenticates and parses the stated equation; it does not
independently recompute the normalization genus.

## Bounded 2-adic chart audit

Modulo 2, the affine equation vanishes only when `x=0`. Both residue classes
for `t` are singular, so ordinary one-step Hensel lifting cannot decide local
solubility. The audit recursively substitutes each surviving residue chart,
divides the exact common power of 2 from its coefficients, and classifies the
four child residues as dead, simple, or still singular.

Through chart depth 12:

- no simple Hensel root appears;
- from depth 3 onward, 12 singular child classes and six dead charts recur at
  each level;
- all 12 classes modulo `2^13` lie in exactly two shrinking neighborhoods:

```text
x =  0 mod 8192,  t = 0 mod 1024   (8 residue classes)
x = -2 mod 8192,  t = 0 mod 2048   (4 residue classes)
```

The centers `(t,x)=(0,0)` and `(0,-2)` are exact rational points at which the
equation and both affine partial derivatives vanish. Thus this gate finds no
additional affine-integral local candidate: every survivor clusters at one of
the two known singular points.

This remains a bounded result. It does not prove that the pattern persists at
all depths, resolve the branches on the normalization, or cover charts with
negative `2`-adic valuation or points at infinity. In particular, it does not
answer König's question whether the smooth curve has a `Q_2` point.

## Provenance and replay

The certificate was generated at revision
`c703d9007d5c8281b11e3c03dd674a8c435d823d` with SageMath 10.9. The official
archive remains external because its distribution terms are not project-owned.

```sh
./scripts/run-8a-sage.sh --python \
  scripts/audit_m24_genus11_model.sage \
  /path/to/Polynomials_And_Approximation_Data.zip \
  --two-adic-chart-depth 12 \
  --check-summary \
    data/derived/m24_koenig_genus11_two_adic_gate.tsv

make check-m24-genus11-model
```

Compact certificate:

```text
b9fa8c77618a878a2f8de78d2c31d484eac4d7b2af792d4d06848513a213e0f2
data/derived/m24_koenig_genus11_two_adic_gate.tsv
```

## Next gate

Compute the exact local normalization or a regular model at `(0,0)` and
`(0,-2)`, then add the nonintegral and infinity charts. The desired outcome is
an all-chart proof that every `Q_2` branch is singular/boundary, or one
explicit nonsingular `Q_2` point with an independently verified lift.
