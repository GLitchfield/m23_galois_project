# Test 0093: exact structure of the 8A coefficient field

## Question

What exact arithmetic structure is visible in the degree-28 coefficient field
of the class-1 Belyi map, and does it already imply a smaller field of
definition?

## Reciprocal involution

The exact defining polynomial `f(T)` from test 0091 is reciprocal. Sage
constructs the number field `K = Q(t)`, verifies `f(t^-1) = 0`, and constructs
the nontrivial involution

```text
iota: t -> t^-1.
```

The field has exactly two `Q`-automorphisms, so this involution accounts for
the complete automorphism group of `K`. The fixed generator `y = t + t^-1`
has irreducible degree-14 polynomial

```text
g(Y) =
Y^14 - 12 Y^13 + 52 Y^12 - 60 Y^11 - 248 Y^10 + 872 Y^9
- 276 Y^8 - 3360 Y^7 + 7292 Y^6 - 5352 Y^5 - 1512 Y^4
+ 4496 Y^3 - 1308 Y^2 - 1344 Y + 768.
```

Exact Laurent-polynomial arithmetic verifies

```text
T^14 g(T + T^-1) = f(T).
```

Since `[K:Q] = 28` and `[Q(y):Q] = 14`, `L = Q(y)` is exactly the fixed field
of `iota`, and `K/L` is quadratic.

## Signatures, automorphisms, and discriminants

| invariant | `K` | `L` |
| --- | ---: | ---: |
| degree | 28 | 14 |
| signature | `(0,14)` | `(2,6)` |
| number of `Q`-automorphisms | 2 | 1 |
| discriminant factorization | `2^66 3^10 11^4 23^6` | `2^31 3^5 11^2 23^3` |

In particular:

```text
D_K / D_L^2 = 16.
```

By the discriminant tower formula, the norm of the relative discriminant of
the quadratic extension `K/L` is 16. The quadratic layer therefore adds
ramification only above 2. Both absolute fields are non-Galois; `K` is totally
imaginary, while `L` has two real and six complex places. This is not a CM
quadratic extension because `L` is not totally real.

## Interpretation and limitation

This structure sharply reduces the next arithmetic question. The 28
coefficient embeddings naturally occur in 14 pairs under `iota`, matching the
size of the 14-component four-point picture that originally led to this
three-point target. That numerical coincidence is suggestive, but it is not
yet an identified action on the Belyi maps.

In particular, coefficients not fixed by `iota` do not automatically descend
to `L`. Descent would require an explicit isomorphism between the map and its
`iota`-conjugate satisfying the cocycle condition, or an equivalent
field-of-moduli calculation. Test 0090's trivial cover-automorphism
centralizer removes one ambiguity but does not manufacture that isomorphism.

Test 0094 performs that calculation. It identifies the conjugate as class 19,
proves an exact source Möbius equivalence after swapping 0 and 1, verifies the
Galois cocycle, and splits it by an unconditional relative-norm/Hilbert--90
calculation. The resulting degree-23 cover is defined over `L`, although its
two finite branch points form an irreducible quadratic pair rather than two
individually `L`-rational Belyi labels.

## Reproduction

```sh
./scripts/run-8a-sage.sh --python \
  scripts/analyze_8a_coefficient_field.sage \
  data/derived/m23_8a_belyi_class1_exact_candidate.json \
  --output /tmp/m23_8a_coefficient_field.tsv

python3 scripts/check_8a_coefficient_field.py \
  /tmp/m23_8a_coefficient_field.tsv
```

The committed artifact is
`data/derived/m23_8a_belyi_class1_coefficient_field.tsv`.
