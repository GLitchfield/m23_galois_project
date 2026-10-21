# Test 0109: König complete normalized mod-19 family recovery

## Question

Can all functions needed to write König's normalized degree-23 cover be
recovered coherently from the plane coordinates, rather than stopping with
the branch parameter `a` from Test 0108?

## Exact target set

The implementation revision is
`db1227be08ae3b994e9c9a79e33d6d2dd360461a`. The authenticated source
archive has SHA-256
`62ce6415db167aeeb816d71fba83fc33b8637515d6c66673105c12b49d07dd44`.

There are fifteen recovered functions:

```text
a, C,
five coefficients of f1 other than beta,
four coefficients of f2 other than alpha,
two unfixed coefficients of g1,
two unfixed coefficients of g2.
```

This corrects an earlier count of fifteen *remaining* functions: after `a`
there are fourteen, namely `C` and thirteen factor coefficients. The plane
coordinates themselves are

```text
alpha = u + 7,
beta  = v + 14.
```

## Denominator-space recovery

The Test 0108 cutoff-105 relation space has dimension 86. Its numerator
projection has rank 50, and
`data/derived/m23_koenig_f19_a_relation_basis.npz` stores a deterministic
50-row independent basis with its schema, code revision, archive hash, Sage
version, monomial specifications, and fitting parameters. Its SHA-256 is

```text
1acf75cec42fe9413b66665c857a2347ec66e43210b5716008e489d43933d4c1.
```

The first arbitrary denominator selected in Test 0108 is not common to the
other coefficients. The full 50-dimensional denominator space is therefore
tested instead.

At 16,384 exact series terms, the family recovery uses the numerator basis

```text
0 <= deg_u <= 96,
0 <= deg_v <= 120.
```

The first 12,000 coefficients give a full-rank `12000 x 11737` matrix. Its
left kernel has dimension 263. For each target `c`, multiplying every one of
the 50 denominator directions by `c` and projecting through this left kernel
gives a small compatibility obstruction.

The obstruction ranks are:

| target group | ranks |
| --- | --- |
| `a` | `0` |
| `C` | `13` |
| `f1_x0,...,f1_x4` | `8,7,8,8,8` |
| `f2_x0,...,f2_x3` | `13,13,12,13` |
| `g1_x0,g1_x1` | `5,5` |
| `g2_x0,g2_x1` | `13,13` |

The intersection of all fifteen compatible denominator kernels has dimension
34. Thus a common denominator exists abundantly even though Test 0108's first
echelon choice was not one.

## Recovered formula set

The deterministic first common direction yields one denominator `D(u,v)`
with:

```text
total degree = 105,
terms        = 5,323,
local valuation at the selected branch = 2.
```

Every recovered numerator is coprime to `D`. Their total degrees range from
100 through 111. The exact sparse artifact is
`data/derived/m23_koenig_f19_family.tsv`, with SHA-256

```text
72d349286bffd45526bc5b0be18477ecf1df162f8aa0eff22f9ec040671e557b.
```

It records one copy of `D` and the fifteen numerators. The formula for target
`c` is `N_c/D`. As in Test 0108, both numerator and denominator may vanish at
the singular plane anchor; the quotient is interpreted on the selected
normalization branch.

The full high-memory replay is:

```sh
make reproduce-koenig-f19-family \
    KOENIG_ARCHIVE=/path/to/Polynomials_And_Approximation_Data.zip
```

Quick and doubled-precision substitution checks are:

```sh
make check-koenig-f19-family
make check-koenig-f19-family-long
```

## Independent validation

The generator fits on 12,000 terms and verifies every recovered numerator on
the remaining 4,384 terms. The independent verifier starts over from the
published mod-19 anchor, does not read the recovery matrices, and lifts all 46
moving coefficients to precision 32,768.

For every one of the fifteen targets it verifies

```text
N_c(alpha-7,beta-14) - c D(alpha-7,beta-14)
    = 0 mod s^32768.
```

This supplies 16,384 coefficients per function that were not available to
the recovery. The compact record is
`data/derived/m23_koenig_f19_family_validation.tsv`.

## Consequence and next gate

The complete normalized mod-19 formula set missing from the public archive
has now been independently reconstructed in rational form, with a
reproducible denominator-space certificate and doubled-precision validation.
This is substantially stronger than recovering `a` alone.

Finite formal agreement is still not, by itself, a global function-field
identity. An exact global probe successfully constructs the degree-23 cover
in `F_19[v,u]/(h)` using staged quotient-ring multiplication, but direct
division of the cleared quadratic branch equation by its degree-16 residual
critical factor causes coefficient blow-up in Sage. The next gate is to
certify that divisibility using a better exact representation or an explicit
quotient witness. Once that passes, the mod-19 plane-to-Hurwitz map is
component-wide; characteristic-zero lifting remains a separate subsequent
step.
