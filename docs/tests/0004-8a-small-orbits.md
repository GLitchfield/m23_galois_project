# Test 0004: small orbits in `(8A)^4`

## Question

Can the rational inner Nielsen class `(8A,8A,2A)` and all small `(8A)^4`
orbits derived from Häfner's size-2, size-6, and size-12 constructions be
reproduced directly?

## Method

Fix an `8A` representative `a`, enumerate every `b` in `8A`, and derive
`c=(ab)^-1`. Retain product-one triples with `c` an involution, quotient under
`C_M23(a)`, and filter for generation.

For every surviving inner class `[a,b,c]`, construct Häfner's three seeds:

```text
[a,a,b,aba^-1]
[a,b,a,b]
[a,b,b,b^-1ab]
```

Canonicalize tuples under simultaneous conjugation, enumerate their pure,
symmetric, and full Hurwitz orbits, and deduplicate across all base classes.
The computation separately checks product-one, generation, membership in `8A`,
orbit sizes, genera, and induced permutation-group orders.

Run:

```sh
make reproduce-8a-small-orbits
make test
```

## Result

- 491 product-one triples after fixing the first coordinate;
- 64 inner classes before generation is imposed;
- 28 generating inner Nielsen classes, matching Häfner;
- 84 distinct pure `B4` orbits of length 2 and genus 0;
- 28 distinct symmetric orbits of length 6 and genus 0;
- 14 distinct full `H4` orbits of length 12;
- each full Hurwitz permutation image has order 96, matching
  `(C2 x C2):S4`.

All counts reported by Häfner for these small `(8A)^4` orbits reproduce.

## Artifact

`data/derived/m23_8a_small_orbits.tsv`
