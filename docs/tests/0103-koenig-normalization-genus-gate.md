# Test 0103: König normalization-genus gate

## Question

Can open-source exact algebra independently certify that König's
bidegree-`(97,98)` plane equation is absolutely irreducible and has
normalization genus 43?

## Provenance

- verifier implementation revision:
  `e7c69487b3403d71ebb7cc0970c6000592f439d5`;
- official archive SHA-256:
  `62ce6415db167aeeb816d71fba83fc33b8637515d6c66673105c12b49d07dd44`;
- SageMath `10.9`, including Singular `4.4.1`; and
- all arithmetic was exact over `Q` or the stated finite field.

## Absolute irreducibility

Yes for the first half.  Exact reduction modulo 11 preserves bidegree and
factors as one exponent-one polynomial over `F_11`.  The verified rational
point `(31/18,0)` has nonsingular reduction.  An irreducible finite-field curve
that becomes reducible over the algebraic closure cannot have a smooth
rational point: such a point would belong to every conjugate component and
their intersection.  The reduction is therefore geometrically irreducible,
which certifies absolute irreducibility of the characteristic-zero equation.

Run:

```sh
make check-koenig-artifacts KOENIG_ARCHIVE=/path/to/archive.zip
```

## Singular rational plane points

The exact derivatives identify two singular reported points.  Direct local
translation gives:

- `(35/9,2/3)` has multiplicity 8 and tangent cone, up to a nonzero rational
  scalar,

  ```text
  (u-17v)(9u-43v)(u-2v)^2(u^2-19uv+134v^2)^2;
  ```

- `(295/288,-11/96)` has multiplicity 2 and tangent cone, again up to scalar,

  ```text
  (19u-27v)^2.
  ```

The first quadratic tangent factor has discriminant `-175`.  These are not
ordinary rational nodes, so their rational plane coordinates do not determine
the residue fields or number of places above them.  The committed archive
verifier checks both tangent-cone identities exactly.

Exact Hamburger--Noether expansions now resolve that ambiguity:

- `(35/9,2/3)` has delta 30, Milnor number 54, Tjurina number 45,
  and seven geometric branches. Their Galois-orbit degrees are
  `(1,1,1,2,2)`: three rational places and two degree-two places. The
  quadratic coefficient field has defining polynomial
  `134a^2-19a+1`, whose discriminant is `-175`, so both quadratic places
  have residue field `Q(sqrt(-7))`.
- `(295/288,-11/96)` has delta 1, Milnor and Tjurina numbers 2, and one
  rational branch. It therefore determines one rational place on the
  normalization.
- the only singular point at projective infinity is `[1:1:0]`. It has
  delta 5, Milnor and Tjurina numbers 9, and one degree-two closed place
  comprising two geometric branches. Its quadratic field is `Q(i)`.

## Exact modular normalization genera

The full singular locus is much larger than the two reported rational
points. The new certificate uses resultants to enumerate every affine
singular stratum, finite-field gcds to recover its `x`-coordinates, the
Hessian to certify ordinary nodes, and exact Hamburger--Noether expansions
for every exceptional stratum.

Run:

```sh
make check-koenig-modular-genus KOENIG_ARCHIVE=/path/to/archive.zip
```

The two geometrically irreducible reductions give:

| Prime | Geometric affine singular points | Ordinary nodes | Exceptional points | Exceptional delta | Affine delta | Infinity delta | Normalization genus |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 13 | 4,571 | 4,563 | 8 | 45 | 4,608 | 5 | 43 |
| 17 | 4,565 | 4,556 | 9 | 52 | 4,608 | 5 | 43 |

The degree-98 projective closure has arithmetic genus 4,656. At both primes
the total delta defect is therefore `4,608+5=4,613`, and the normalization
genus is exactly `4,656-4,613=43`. The differing singular decompositions
provide a useful guard against one prime's accidental local pattern.

Reduction genus is a lower bound for the characteristic-zero normalization
genus: special fibers can acquire extra singularities. Thus these two exact
certificates do not, by themselves, replace either an exact
characteristic-zero global delta sum or a certified dominant map from the
independently computed genus-43 Hurwitz component to this plane model. They
do show exact agreement with the claimed genus at two distinct
characteristics and reduce the remaining logical gap to that comparison.

## Bounded normalization probes

Three exact open-source methods were run with hard wall-clock bounds:

| Method | Bound | Outcome |
| --- | ---: | --- |
| Sage/Singular projective plane genus over `Q` | 3,600 s | timed out after reporting degree 98 and arithmetic genus 4,656 |
| Sage/Singular projective plane genus over `F_11` | 1,800 s | timed out after reporting the same degree and arithmetic genus |
| Sage degree-98 function field over `Q(t)` | 3,600 s | timed out after constructing the extension |

The commands are reproducible:

```sh
scripts/probe-koenig-normalization-genus.sh ARCHIVE plane-qq 3600
scripts/probe-koenig-normalization-genus.sh ARCHIVE plane-mod-p 1800 11
scripts/probe-koenig-normalization-genus.sh ARCHIVE function-field 3600
```

A timeout is not evidence against genus 43.  It rejects these monolithic calls
as practical certificate generators on the current 32 GiB host.

## Next exact algorithm

The modular local-delta algorithm and the branches above both known singular
rational points are complete. The remaining strict characteristic-zero genus
gate can now be closed in either of two ways:

1. produce a certified dominant map from the independently computed genus-43
   `C2`-symmetrized Hurwitz component to this absolutely irreducible plane
   model; the modular lower bound then forces equality. Test 0104 audits this
   map numerically on the complete fiber and specifies the exact tautological
   family needed to certify it; or
2. lift/decompose the characteristic-zero Jacobian strata and certify a
   global delta sum of 4,613 directly.

Magma access would be valuable for a one-off independent `IsAbsolutelyIrreducible`
and `Genus(Normalization(...))` comparison, but the open-source project is not
blocked: it now has two exact modular genus certificates, exact rational-point
branch data, and a narrowly stated characteristic-zero comparison gate.
