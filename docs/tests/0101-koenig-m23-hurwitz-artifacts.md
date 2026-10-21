# Test 0101: König's explicit M23 Hurwitz curve

## Question

Can the primary thesis artifacts for the `(2A,2A,3A,5A)` route be recovered,
authenticated, and reconciled with an independent braid computation?

## Primary material and custody

The Würzburg OPUS record for Joachim König's 2014 dissertation provides:

- the [dissertation PDF](https://opus.bibliothek.uni-wuerzburg.de/opus4-wuerzburg/files/10014/Koenig_Joachim_Dissertation.pdf),
  SHA-256
  `f676b3f5d00a4d9960ea10e2032f86321741a201751c3e6b9d55f787c60a1618`;
- the official [polynomials and approximations archive](https://opus.bibliothek.uni-wuerzburg.de/opus4-wuerzburg/files/10014/Polynomials_And_Approximation_Data.zip),
  SHA-256
  `62ce6415db167aeeb816d71fba83fc33b8637515d6c66673105c12b49d07dd44`.

The archive is 13.8 MB (the relevant approximation member is 19.1 MB
uncompressed), and its OPUS metadata applies German copyright rather than an
open-source license. It is therefore kept outside the repository.
`scripts/verify_koenig_m23_artifacts.py` authenticates a local copy and checks
the two relevant members without extracting or modifying them.

## Independent braid computation

Reorder the class vector as `(3A,5A,2A,2A)`, fix the first `3A` element, and
enumerate all ordered involution pairs. The product-one condition determines
the `5A` entry. Quotient by the order-180 centralizer, test generation directly
in `MathieuGroup(23)`, and compute the induced pure and `C2`-symmetric braid
permutations.

Run:

```sh
make reproduce-koenig-orbit
make check-koenig-orbit
```

The result is:

- 1,526,400 fixed-first product-one tuples;
- 8,490 inner classes before generation is imposed;
- exactly 980 generating inner Nielsen classes;
- one 980-class pure braid orbit of genus 119;
- one 980-class orbit after swapping the two equal `2A` positions, of genus
  43.

This resolves an earlier ambiguity. Genus 119 belongs to the ordered/pure
Hurwitz curve. The curve König computes is the `C2`-symmetrized genus-43
quotient.

## Exact archive checks

Given the downloaded archive:

```sh
make check-koenig-artifacts KOENIG_ARCHIVE=/path/to/Polynomials_And_Approximation_Data.zip
```

The standard-library check verifies:

- the archive hash and exact member sizes;
- that `m23_(2,2,3,5)_approx.txt` is a top-level list of 980 entries;
- that the exact curve file claims genus 43 and contains a polynomial of
  bidegree `(97,98)`.

The Sage check parses the 1.2 MB integer polynomial exactly. It verifies all
four vertices of its Newton polygon as
`(0,0), (97,0), (96,2), (0,98)`, and all five rational points reported in
Proposition 5.7,

```text
(31/18,0), (5/9,2/3), (35/9,2/3), (410/9,2/3),
(295/288,-11/96),
```

and verifies from the two partial derivatives that precisely the first,
second, and fourth points in that list are nonsingular.

It also reduces the exact polynomial modulo 11 without changing its
bidegree.  Exact finite-field factorization returns one exponent-one factor,
and `(31/18,0)` reduces to a nonsingular `F_11` point.  If an irreducible
finite-field curve were geometrically reducible, every rational point would
lie in the intersection of its conjugate components and would be singular.
The reduction is therefore geometrically irreducible, which certifies that
the characteristic-zero polynomial is absolutely irreducible.

## What this proves and does not prove

The repository now independently verifies the finite 980-class braid
calculation, the pure/symmetric genus distinction, and exact identities in
König's archived equation, including its absolute irreducibility. Two exact
reductions independently have normalization genus 43. A strict
characteristic-zero equality still requires a global delta certificate or a
certified map from the braid component to the plane model.

The derivative check also shows that the third and fifth displayed rational
plane points are singular.  A rational singular point of a plane model need
not lift to a rational place on its normalization.  Consequently those two
points cannot be used in an arithmetic argument until the branches above them
and their residue fields are computed exactly.

König reports numerical and finite-field evidence that all five rational
places correspond to degenerate three-point covers, and states that the
associated three-point groups are proper subgroups of `M23`. The present
checks do not promote that boundary identification to a new exact
certificate. In particular, these rational points do not supply an
`M23/Q` realization.

Test 0103 resolves the branches over both singular rational plane points:
`(35/9,2/3)` has three rational and two quadratic closed places, while
`(295/288,-11/96)` has one rational place. The remaining part of the first
stopping gate is therefore the exact characteristic-zero genus comparison.
On failure, the identification of this plane model with the braid-computed
Hurwitz curve must be re-examined.

After that gate, recover or reconstruct the map from the normalized curve to
the universal-cover coefficients and its degeneration divisor, then
distinguish rational interior places from boundary places.  Before claiming
that a rational point on the `C2`-symmetrized curve produces a regular
`M23/Q(t)` cover, the precise reduced/inner fine-moduli and descent statement
for the conjugate pair of `2A` branch points must also be pinned to a primary
source.  This is a substantially better-defined arithmetic route than merely
searching for another small four-branch component.
