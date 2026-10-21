# Test 0070: LMFDB degree-23 local-field reconnaissance

## Question

Can LMFDB data help with the 8A arithmetic search even though its Belyi-map
database stops below degree 23?

## Coverage and useful records

Yes, as a validation library rather than as a source of the missing map.  The
LMFDB states that its p-adic field data are complete for degrees below 24 and
residue characteristics below 200.  In particular, it contains the complete
degree-23 local catalogue at the primes most likely to matter in a future
candidate coefficient field.

Two representative totally ramified `Q_23` records inspected on 2026-07-21
are:

- [`23.1.23.30a2.3`](https://www.lmfdb.org/padicField/23.1.23.30a2.3), with
  local Galois group `23T3 = C23:C11`; and
- [`23.1.23.32a1.5`](https://www.lmfdb.org/padicField/23.1.23.32a1.5), with
  local Galois group `23T4 = C23:C22` and inertia `23T3`.

The first is an `M23`-compatible local decomposition group; the second is a
particularly useful negative control.  The global degree-23 `23T3` number
fields in the [LMFDB search](https://www.lmfdb.org/NumberField/?galois_group=23T3)
and the larger Kluners--Malle list are likewise fixtures, not realizations of
`M23`.

## Independent group-theoretic filter

GAP's complete degree-23 transitive-group library has seven groups.  The four
solvable ones, which are the candidates for a transitive local decomposition
group, are

```text
23T1  C23
23T2  D46
23T3  C23:C11
23T4  C23:C22.
```

An exact subgroup calculation inside `M23 = 23T5` finds copies of `23T1` and
`23T3`, but none of `23T2` or `23T4`.  Therefore a candidate global degree-23
field with an irreducible local factor having group `23T2` or `23T4` cannot
have global Galois group `M23`.  A `23T1` or `23T3` completion is compatible
but does not prove the global group.

This gives a cheap and rigorous rejection test for future candidate number
fields.  At unramified primes, ordinary factor degrees additionally give the
Frobenius cycle partition, which can be compared with the cycle types occurring
in the natural action of `M23`.  At ramified primes 2 and 23, LMFDB's inertia,
wild inertia, discriminant exponent, and slope data provide richer comparison
fixtures.

## Boundary

Local fields do not determine the Galois action on the 28 Belyi maps and do not
replace computing an equation.  A decomposition group is only a subgroup of a
global Galois group, and several global groups share the same local behavior.
The data become actionable after an exact candidate coefficient field or a
specialized degree-23 polynomial is available.

## Reproduction

```sh
./scripts/check-degree23-local-groups.sh
```

The web records are cited with retrieval date because LMFDB is a live database;
the group-containment conclusion is independently regenerated from the pinned
GAP/transgrp versions in the repository environment.

## Sources

- [LMFDB completeness of p-adic field data](https://www.lmfdb.org/padicField/Completeness).
- J. Guardia Rubies, J. W. Jones, K. Keating, S. Pauli, D. P. Roberts, and
  D. Roe, [*Families of p-adic fields*](https://arxiv.org/abs/2507.02360).
