# Test 0110: König exact global mod-19 critical-value identity

## Question

Do the fifteen rational functions recovered in Test 0109 define the expected
two residual critical values globally on the mod-19 plane curve, rather than
only agreeing along one finite formal branch?

## Exact identity

Let

```text
K = Frac(F_19[u,v]/(h(u+7,v+14))),
```

where `h` is the authenticated plane equation. Its reduction modulo 19 is
irreducible. Write the Test 0109 common denominator as `D`, its numerators as
`N_c`, and clear the factor coefficients:

```text
f1_bar = D f1,  f2_bar = D f2,
g1_bar = D g1,  g2_bar = D g2.
```

The moving plane coefficients are included in this clearing, so the
coefficient of `X^5` in `f1_bar` is `D(v+14)` and that of `X^4` in `f2_bar`
is `D(u+7)`. Put

```text
G = g1_bar^5 g2_bar,
A = N_C D f1_bar^3 f2_bar - 5G,
E = D A^2 - N_a G^2,
```

and let

```text
R =
  (3 f1_bar' f2_bar + f1_bar f2_bar') g1_bar g2_bar
  - f1_bar f2_bar
      (5 g1_bar' g2_bar + g1_bar g2_bar').
```

Here derivatives are with respect to the cover variable `X`. The certified
identity is

```text
R divides E in K[X].
```

After undoing the harmless powers of `D`, this is precisely

```text
R_actual divides
  (C f1^3 f2 - 5 g1^5 g2)^2 - a (g1^5 g2)^2.
```

Thus every root of the residual degree-16 critical factor maps to the
quadratic branch locus `(t-5)^2=a`, wherever the rational family is defined.

## Why modular division is conclusive

Direct long division in `K[X]` causes severe coefficient growth. The
certificate instead uses pseudo-division and a deterministic degree bound.
For the weights

```text
wt(u)=2, wt(v)=1,
```

every term of the translated plane equation has weight at most 194, equal to
the weight of its constant-leading-coefficient `u^97` term. Reduction modulo
the plane equation therefore cannot increase weight.

A max-plus replay of the cleared factor products and all 31 pseudo-division
steps bounds every `v`-coefficient in the normal-form remainder by

```text
28,539.
```

The committed certificate contains 224 distinct monic irreducible
degree-128 polynomials in `F_19[v]`. For every modulus:

1. the leading coefficient of `R` is a unit in the specialized plane
   algebra; and
2. exact monic division of the degree-46 polynomial `E` by the degree-16
   polynomial `R` has zero remainder.

Consequently every stored irreducible modulus divides every coefficient of
the global pseudo-remainder. Their total degree is

```text
224 * 128 = 28,672 > 28,539.
```

A nonzero coefficient cannot have that many roots, so the global remainder
is zero. This is a deterministic exhaustiveness argument, not probabilistic
polynomial identity testing.

## Evidence and replay

The implementation revision is
`640dc7ef0ce81b0f7120fe3189c1a150ff4bda07`. The family SHA-256 remains

```text
72d349286bffd45526bc5b0be18477ecf1df162f8aa0eff22f9ec040671e557b,
```

and the authenticated archive SHA-256 remains

```text
62ce6415db167aeeb816d71fba83fc33b8637515d6c66673105c12b49d07dd44.
```

The canonical 73 KB certificate is
`data/derived/m23_koenig_f19_global_certificate.tsv`, with SHA-256

```text
bc9f90c4d058b10326eed9adadadea46900c2ac0b14fcd4acd6d88f951754bb4.
```

It records every irreducible modulus, the unit-leading-coefficient check,
the zero-remainder result, the bound, versions, hashes, and revisions. The
full run is deterministically sharded, atomically checkpointed after every
modulus, and resumable:

```sh
make reproduce-koenig-f19-global \
    KOENIG_ARCHIVE=/path/to/Polynomials_And_Approximation_Data.zip
```

The ordinary verification target checks all modulus encodings and
irreducibility proofs, reconstructs the degree bound, and freshly replays one
exact division:

```sh
make check-koenig-f19-global \
    KOENIG_ARCHIVE=/path/to/Polynomials_And_Approximation_Data.zip
```

`make check-koenig-f19-global-long` replays all 224 divisions.

## Consequence and remaining gate

Test 0109's local rational candidates now satisfy the central residual
critical-value relation globally in the mod-19 plane function field. This
removes the coefficient-growth obstacle identified there.

This is not yet a characteristic-zero `M23` polynomial. The next exact gate
is to certify generic factor coprimality, separability, and the full
`(2^8 1^7,2^8 1^7,3^6 1^5,5^4 1^3)` branch partitions for this rational
family. That would make the mod-19 plane-to-Hurwitz construction explicit.
Lifting or reconstructing it in characteristic zero remains a separate
subsequent step.
