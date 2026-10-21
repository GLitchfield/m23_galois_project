# Test 0058: Lean certificate for the small 8A tuple assignments

## Question

Can Lean check the concrete degree-23 permutation witnesses behind the
test-0056 complex-conjugation action on all fourteen small `(8A)^4` full
Hurwitz components?

## Inputs and provenance

- implementation: the commit containing this note;
- GAP `4.12.1`, AtlasRep `2.1.8`, and CTblLib `1.3.7`;
- group construction `MathieuGroup(23)`;
- Lean `4.29.1` and the pinned mathlib manifest under `formal/`; and
- deterministic witness artifact
  `data/derived/m23_8a_component_witnesses.tsv`.

The GAP reproduction records permutations by the images of points 1 through
23. It emits 168 tuple records, 504 adjacent-Hurwitz edge records, and 168
prefix-conjugated-inversion records. Every edge and inversion record contains
an explicit degree-23 permutation conjugating the computed image to its stated
canonical destination.

## Independent checks

The Python-to-Lean generator rejects malformed or missing records and
independently recomputes permutation multiplication, inverses, Hurwitz moves,
prefix-conjugated inversion, simultaneous conjugation, graph connectivity,
and the component map. The generated Lean module is compared byte-for-byte on
every formal check.

Lean then reduces the certificate in its kernel. For each of the fourteen
components it checks:

- all tuple and conjugator tables are genuine permutations;
- all twelve tuples are product one and have four elements of exact order 8;
- all 168 canonical tuples are pairwise distinct;
- all 36 adjacent-Hurwitz edge equations;
- reachability of all twelve vertices from the first vertex;
- all twelve prefix-inversion/conjugation equations; and
- agreement of every destination with the test-0056 component table.

Run:

```sh
make check-lean
```

The underlying GAP artifact is reproduced by:

```sh
make reproduce-8a-small-orbits
```

## Result

Passed. The concrete tuple witnesses give the same component action

```text
(1 12)(2 11)(3)(4 13)(5 9)(6)(7 10)(8 14).
```

Thus the claim that components 3 and 6 are the only survivors of the
complex-conjugation filter no longer rests on an unchecked tuple-to-component
summary table.

## Boundary and verdict

Lean treats the records as permutations of 23 points and verifies the stated
permutation equations. It does not yet prove internally that the generated
group is isomorphic to `M23`, that the entries occupy ATLAS class `8A`, or the
geometric branch-cycle theorem that interprets prefix inversion as complex
conjugation on covers. GAP continues to replay the first two group-theoretic
facts; the last is a published-theorem boundary.

Passed as the tuple-level certificate for test 0056. The next mathematical
gate is the remaining absolute-Galois action on full components 3 and 6.

Test 0059 subsequently used the same edge tables to prove that all fourteen
ordered degree-12 braid actions are isomorphic, eliminating action-signature
uniqueness as a way to settle that gate.

Tests 0061 and 0062 extend this same certificate without changing that gate:
Lean checks the pair-product order labels used in the rational-boundary audit
and verifies that no certified small-component tuple factors into two inverse
pairs.

## Artifacts

- `data/derived/m23_8a_component_witnesses.tsv`;
- `formal/M23Formal/Permutations/Degree23.lean`;
- `formal/M23Formal/Certificates/Test0058Data.lean`; and
- `formal/M23Formal/Certificates/Test0058.lean`.
