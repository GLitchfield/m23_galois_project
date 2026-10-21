# Test 0095: exact absolute-Galois orbit of the 8A cover

## Question

What are the exact absolute-Galois orbit and field-of-moduli degrees of the
degree-23 `(8A,8A,2A)` cover, and can any member of this passport be defined
over `Q`?

## Canonical ordered invariant

The infinity branch point is intrinsic because its partition
`(2^8,1^7)` differs from the common finite partition `(8,8,4,2,1)`.
Choose either finite branch point as zero and the other as one. In the chosen
zero fibre, the ramification points of multiplicities 1, 4, and 2 are unique,
so sending them to `0`, `1`, and infinity gives a canonical source
normalization.

In that normalized map, let `c2` be the unique multiplicity-2 point in the
opposite finite fibre. It is an isomorphism invariant of the ordered cover.
Exact factorization gives

```text
degree(minpoly(c2)) = 28.
```

The ordered cover is already defined over the degree-28 coefficient field
`K`, so its ordered field of moduli and absolute-Galois orbit both have degree
28.

## Forgetting the finite branch order

Test 0094 proves the exact identity

```text
iota(phi)(mu(x)) = 1 - phi(x),
```

where `iota(t)=t^-1`. Thus choosing the other finite branch produces the
canonical conjugate map, and its opposite-fibre multiplicity-2 invariant is
`iota(c2)`. The unordered cover therefore has the symmetric invariant

```text
J = c2 + iota(c2).
```

Exact arithmetic proves that `J` is fixed by `iota` and has degree 14. A
primitive integral multiple of its minimal polynomial is

```text
135000*J^14 - 14347800*J^13 + 763643529*J^12
- 21354522368*J^11 + 264713104302*J^10
- 1833965531280*J^9 + 8766641722687*J^8
- 31542190380928*J^7 + 65698634974996*J^6
- 83926575826136*J^5 + 75920835474239*J^4
- 26162953890080*J^3 + 10935826538118*J^2
+ 3129161589728*J + 1996068900649.
```

Because `J` lies in the reciprocal fixed field and already has degree 14, it
generates that field. Test 0094 supplies an explicit model of the unlabelled
cover over the same degree-14 field. The lower and upper bounds therefore
meet: the unlabelled field of moduli and absolute-Galois orbit have degree 14.

## Exhausting the passport

The independently enumerated passport ledger contains exactly 28 generating
ordered classes. Since the class-1 ordered orbit already has size 28, it
contains every ordered map in the passport. The reciprocal involution pairs
the two finite branch choices, so the fourteen unlabelled pairs likewise form
one orbit of size 14.

Consequently:

- all 28 ordered `(8A,8A,2A)` maps form one absolute-Galois orbit;
- all 14 finite-branch-unlabelled covers form one absolute-Galois orbit;
- no cover in this three-point passport is defined over `Q`.

This is a negative result for this direct three-point descent route only. It
does not rule out `M23/Q` through a four-branch Hurwitz space, specialization,
or a different passport.

## Independent verification

The producer factors the two finite fibres and checks the exact branch-swap
identity directly. The verifier instead reconstructs the multiplicity layers
using derivative gcds, independently recovers `c2` and `J`, recomputes both
minimal polynomials, checks the degree-14 descended field, and counts the
complete 28-class ledger. No Magma calculation or numerical embedding enters
the result.

## Reproduction

```sh
./scripts/run-8a-sage.sh --python \
  scripts/analyze_8a_absolute_orbit.sage \
  data/derived/m23_8a_belyi_class1_exact_candidate.json \
  data/derived/m23_8a_class1_degree14_descended_cover.json \
  data/derived/m23_8a_8a_2a_inner_classes.tsv \
  --output /tmp/m23_8a_absolute_orbit.tsv

./scripts/run-8a-sage.sh --python \
  scripts/check_8a_absolute_orbit.sage \
  /tmp/m23_8a_absolute_orbit.tsv
```

Committed evidence:

- `data/derived/m23_8a_belyi_absolute_orbit.tsv`.
