# Test 0081: exact related-start boundary audit

## Question

Can 26 of the 28 committed `(8A,8A,2A)` targets, including class 22, be
placed on one boundary of an explicit four-point Nielsen problem whose
opposite boundary contains genus-zero three-point `M23` covers?

## Method

For each of the 28 committed target representatives `(a,b,c)`, enumerate in
the natural degree-23 copy of `M23` every factorization

```text
a = h k,  with h in 2A and k in 3A.
```

This gives product-one four-tuples `(h,k,b,c)` in the class vector
`(2A,3A,8A,2A)`.  Colliding entries 1 and 2 recovers the target triple
`(hk,b,c)`.  Colliding the cyclically adjacent entries 4 and 1 instead gives
the opposite-boundary triple `(ch,k,b)`.  GAP checks class membership,
product one, and generation separately.

The source triples of passport `(4A,3A,8A)` are then enumerated
with the `8A` entry fixed, quotiented by its centralizer, and assigned stable
lexicographic IDs.  A Python checker independently re-parses every degree-23
permutation and verifies the passports, products, target merge, opposite
merge, exported source-ID equality, cross-table counts, hashes, and recorded
provenance.  GAP remains the authority for membership in `M23`, generation,
the 227-orbit census, and the conjugation used to assign canonical source IDs.

## Result

Passed as a finite branch-cycle correspondence.

- Every target representative has exactly 20 `2A * 3A` factorizations, for
  560 generating four-tuples in total.
- The opposite collision produces 142 `(4A,3A,8A)` boundary-lift instances,
  of which 88 generate `M23`; these links cover 26 of the 28 target classes.
- There are 227 inner classes in the full `(4A,3A,8A)` passport and exactly 54
  generating inner classes.  Riemann--Hurwitz gives genus zero.
- The 88 links meet 48 of those 54 generating source classes; this is an
  existence correspondence, not a claim that every source class is linked.
- Target class 22 has three exact genus-zero links: factor indices 2, 9, and
  18 lead to canonical source classes 44, 27, and 8 respectively.
- The same four-point construction also has generating opposite boundaries of
  type `(5A,3A,8A)` and `(6A,3A,8A)`, both of genus one, covering all 28 target
  classes.

The Magma export contains all 54 genus-zero source triples and identifies
source IDs 8, 27, and 44 as the class-22 candidates.  The export is suitable
input to the public Belyi package; no source equation was computed.

## Homotopy interpretation and limit

This closes the *combinatorial* part of the related-start gate for the 26
covered targets.  Each recorded source and target pair occurs as two boundary
degenerations of the same explicit four-tuple.  It does not yet supply the
algebraic family or analyze the braid components containing the 88
four-tuples.
The related-start homotopy was not pursued: the exact class-1 target map was
later obtained by the Barth--Wenz route (tests 0086--0091), and the 8A route
closed negatively (tests 0095--0098).

Noam Elkies' published degree-23 `M23` polynomial is an important end-to-end
benchmark, but its three-point passport is `(23A/23B,2A,4A)`, not the
`(4A,3A,8A)` source passport found here.  This audit neither proves nor rules
out a different multi-boundary relation through Elkies' cover.  A targeted
literature search found no published equations for this exact source passport;
absence from that search is not a mathematical nonexistence claim.

## Evidence and reproduction

- `data/derived/m23_8a_related_start_boundaries.tsv`;
- `data/derived/m23_8a_related_start_target_coverage.tsv`;
- `data/derived/m23_4a_3a_8a_inner_classes.tsv`;
- `data/derived/m23_8a_related_start_links.tsv`;
- `data/derived/m23_4a_3a_8a_belyi_input.m`;
- `scripts/gap/audit_8a_related_start_boundaries.g`;
- `scripts/gap/generate_8a_related_start_source_classes.g`; and
- `scripts/check_8a_related_start_evidence.py`.

Reproduce and independently check everything with:

```console
make reproduce-8a-related-start
make check-8a-related-start
```

The source-generation revision, GAP version, group construction, target path,
and target SHA-256 are embedded in every TSV artifact.  The Magma export also
records its source-table SHA-256.

## Advisory review

Claude Fable 5 and Codex GPT-5.4 reviewed the full 110 KB evidence packet at
revision `a58deea` with one reciprocal critique round.  Both found the
right-action convention and headline counts internally consistent.  Their
useful objection was that the first draft overstated the Python checker's
independence: it does not replace GAP for `M23` generation, orbit completeness,
or canonical conjugacy.  The Method and Result sections above now state that
boundary explicitly and name both the 26-of-28 target coverage and the
48-of-54 source coverage.  The review is advisory and is not included as
mathematical evidence.
