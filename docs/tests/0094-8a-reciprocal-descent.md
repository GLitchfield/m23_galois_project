# Test 0094: reciprocal class action and degree-14 descent

## Question

How does the reciprocal field involution act on the exact class-1 cover, and
does its color-swapping descent datum split over the degree-14 fixed field?

## Exact reciprocal identity

Let `K = Q(t)` be the degree-28 coefficient field, let
`iota(t) = t^-1`, and write the exact Belyi map as `phi = P/Q`.
The normalization fixes the unique multiplicity-1, multiplicity-4, and
multiplicity-2 points of the zero fibre at `0`, `1`, and infinity.
Consequently, an ordered equivalence between `phi` and `iota(phi)` would have
to use the identity source Möbius map. Exact cross multiplication proves that
no such ordered equivalence exists.

The one fibre has unique points `c1`, `c4`, and `c2` of those same
multiplicities. They determine the only possible color-swapping source map:

```text
mu(x) = (x-c1)(c4-c2) / ((x-c2)(c4-c1)).
```

Exact rational-function arithmetic proves

```text
iota(phi)(mu(x)) = 1 - phi(x)
iota(mu)(mu(x)) = x.
```

Thus the reciprocal involution exchanges the two finite branch colors and
supplies a genuine quadratic descent cocycle. Swapping the two certified
finite monodromy permutations and comparing against the complete 28-row
ledger identifies the reciprocal equation uniquely as inner class 19. GAP
again gives group order `10,200,960`, structure `M23`, and trivial
degree-23 centralizer.

## Splitting the source twist

Let `M` be the matrix of `mu`. Its cocycle product has the form

```text
iota(M) M = lambda I,  lambda in L,
```

where `L = Q(t+t^-1)` is the degree-14 fixed field. Sage's unconditional
relative-norm algorithm proves that `lambda` is a norm from `K/L` and returns
a witness `r`. After replacing `M` by `N=M/r`, exact matrix arithmetic gives

```text
iota(N) N = I.
```

The deterministic Hilbert--90 matrix `A=I+N` is nonsingular and satisfies

```text
iota(A) N = A.
```

This explicitly trivializes the source `PGL2` cocycle: the descended source
curve is `P1` over `L`, not a nonsplit conic.

## The descended cover

Set

```text
y = t + t^-1,
s = t - t^-1,       s^2 = y^2 - 4,
W = s (z - 1/2),
U = A(x).
```

Substituting `x=A^-1(U)` into `W=s(phi(x)-1/2)` produces a degree-23 rational
function whose coefficients are fixed by `iota`. They are exported exactly
in the degree-14 field `L`.

The descended branch locus is

```text
W^2 - (y^2 - 4)/4 = 0,   together with infinity.
```

The finite quadratic is irreducible over `L`. After adjoining its two roots,
an independent verifier proves the ramification partitions

```text
negative finite root   (8,8,4,2,1)
positive finite root   (8,8,4,2,1)
infinity               (2,2,2,2,2,2,2,2,1,1,1,1,1,1,1)
Riemann--Hurwitz sum   44.
```

## Interpretation

Pass as an exact degree-23 three-point cover over the degree-14 field `L`,
with geometric monodromy `M23` inherited from the certified base change.

This is not an ordered Belyi map over `L`: the two finite branch points form
one quadratic pair and are not individually `L`-rational. Marking them as
0 and 1 recovers the degree-28 extension `K`. The calculation therefore
explains the factor of two in the original coefficient field rather than
silently erasing it.

It is also not an `M23/Q` realization. Test 0095 completes the next arithmetic
question: a canonical invariant proves that the degree-14 unlabelled field of
moduli is minimal and that the resulting orbit exhausts all fourteen
finite-branch-unlabelled pairs.

## Reproduction

```sh
./scripts/run-8a-sage.sh --python \
  scripts/analyze_8a_reciprocal_descent.sage \
  data/derived/m23_8a_belyi_class1_exact_candidate.json \
  data/derived/m23_8a_belyi_class1_interval_monodromy.tsv \
  --output /tmp/m23_8a_reciprocal_descent.tsv \
  --cover-output /tmp/m23_8a_degree14_cover.json

python3 scripts/check_8a_reciprocal_descent.py \
  /tmp/m23_8a_reciprocal_descent.tsv \
  /tmp/m23_8a_degree14_cover.json

./scripts/run-8a-sage.sh --python \
  scripts/verify_8a_descended_cover.sage \
  /tmp/m23_8a_degree14_cover.json
```

Committed evidence:

- `data/derived/m23_8a_belyi_class1_reciprocal_descent.tsv`;
- `data/derived/m23_8a_class1_degree14_descended_cover.json`.
