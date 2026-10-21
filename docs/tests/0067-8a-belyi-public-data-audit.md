# Test 0067: public-data and ambient-passport audit for the 8A Belyi target

## Question

Is an equation for the degree-23 passport

```text
(8,8,4,2,1), (8,8,4,2,1), (2^8,1^7)
```

already present in the principal public Belyi databases or indexed literature,
and can a passport-only algebraic solve be expected to isolate the 28 refined
`M23` classes?

## Public-data audit

The audit was performed on 2026-07-21, including all six permutations of the
three branch partitions and searches by `M23`, `23T5`, `(8A,8A,2A)`, and the
expanded cycle partitions.

- The current [LMFDB Belyi statistics](https://www.lmfdb.org/Belyi/stats) state
  that its 1,111 Galois orbits and 1,007 passports have degree at most 9.  A
  degree-23 record therefore cannot currently occur there under a reordered
  label.
- The public [BelyiDB repository](https://github.com/michaelmusty/BelyiDB) was
  inspected at commit `7d5b899b0741ebd505363f7f811e5737e906abee`.  Its
  `belyi_db/` data directories are exactly degrees 1 through 9.  This agrees
  with the LMFDB coverage statement.
- Sijsling--Voight Example 7.9 counts a different degree-23 `M23` passport,
  `(4^4,2^2,1^3)/(4^4,2^2,1^3)/(5^4,1^3)`.  It establishes the usefulness of
  working inside `M23`, but does not supply the present equation.
- Elkies gives an explicit degree-23 `M23` Belyi polynomial with passport
  `(2^8,1^7)/(4^4,2^2,1^3)/(23)`.  It is not one of the present 28 maps, but
  its eight-variable normalized equation, finite-field seed, algebraic lifting,
  and later monodromy certification make it a valuable benchmark.

No indexed exact equation for the target passport was found.  This is an audit
of specified public sources, not proof that no private or differently described
calculation exists.

## Ambient scaling calculation

The ordinary cycle passport does not isolate `M23`.  GAP character-table
structure constants give the weighted simultaneous-conjugacy mass

```text
S23 cycle passport:            1024815269/1024
M23 refined (8A,8A,2A) mass:   491/8
```

The mass is the number of product-one triples weighted by the reciprocal of
their simultaneous centralizer.  It includes nontransitive or nongenerating
triples and is not an unweighted map count.  Nevertheless, the roughly
one-million ambient mass is a decisive scaling warning: a polynomial system
that imposes only the three cycle partitions contains vastly more than the 28
generating `M23` dessins.  A modular or characteristic-zero solution must be
connected back to a certified `M23` permutation triple; passport alone is not
enough.

The `M23` mass also exceeds 28 because it includes nongenerating triples and
centralizer weights.  The committed direct enumeration remains the certificate
for the exact 28 generating inner classes.

## Result

The public-database search has a structural negative answer rather than a weak
name-query answer: the two principal databases stop at degree 9.  The best
new positive lead is Elkies' published degree-23 computation as a validation
and method benchmark.  A blind solve of the ambient passport is not a credible
replacement for a dessin-seeded numerical computation.

## Reproduction

```sh
./scripts/check-8a-belyi-passport-audit.sh
```

## Primary sources

- J. Sijsling and J. Voight,
  [*On computing Belyi maps*](https://doi.org/10.5802/pmb.5), Example 7.9.
- N. Elkies,
  [*The complex polynomials P(x) with Gal(P(x)-t) = M23*](https://doi.org/10.2140/obs.2013.1.359).
- [LMFDB Belyi statistics](https://www.lmfdb.org/Belyi/stats).
- [Public BelyiDB repository](https://github.com/michaelmusty/BelyiDB).
