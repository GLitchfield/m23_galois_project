# Test 0096: adversarial review and the post-0095 strategy gate

## Question

What does the completed three-point calculation actually prove, and which
next calculation has the highest direct value for the `M23/Q` problem?

## Review protocol

The read-only adversarial-review harness gave Claude Fable 5 and GPT-5.4 the
same 142 KB evidence packet, then gave each model the other's initial report
for one reciprocal critique.  The packet covered tests 0091--0095 and their
producer/checker code, the complete three-point census, the small four-branch
8A calculations, the 5A feasibility work, Seguin's construction, the
literature basis, and the active roadmap.

The review used repository revision
`2aafb54a364c67aabb344e0689d6f6ce09be80d1` and packet SHA-256
`e7c6f7d6da29d925ce2799c78f5efd26a9b0a1d7db599378c17e78dcb3c68997`.
Both final reports rated the position `partially_supported` with medium
confidence.  The raw model transcripts remain ignored run data; this note
records only the resulting research decision.  Model review is advisory and
is not mathematical evidence.

## Agreed conclusions

Both reviewers accepted the Test 0095 conclusion within its stated dependency
chain:

1. Test 0064 supplies the complete 28-class ordered census.
2. Test 0092 certifies that the exact map has the intended geometric
   monodromy and identifies its inner Nielsen class.
3. Test 0095 gives degree-28 and branch-symmetric degree-14 invariants.
4. Standard branch-cycle, Riemann-existence, and field-of-moduli theory
   converts those exact calculations into one ordered orbit of size 28 and
   one unlabelled orbit of size 14.

Thus the direct three-point conclusion stands: this passport contains no
`Q`-defined cover.  It is not an obstruction to `M23/Q` by another passport,
nor does it by itself decide the small four-branch 8A components.  A public
proof package should make the imported census and theorem-level dependencies
as prominent as the invariant calculation.

The reviewers also agreed that transitivity, or merely knowing an orbit size,
does not automatically transfer through the existing boundary-incidence
table.  The project needs either the actual finite action or a sharper
structural argument, together with a convention-clean application of the
Cau--Seguin Galois-equivariance theorem to the marked/inner/full quotients
used here.

## Sharpening found during reconciliation

Two bounded local probes make that next seam substantially more promising.
They are feasibility observations to be packaged as independent certificates
in the next test, not new proved claims of Test 0095.

- OSCAR 1.7.3 with Hecke 0.39.15 identifies the degree-14 fixed-field
  polynomial's Galois group as `S14`, of order `87178291200`.
- Exact modular factorization gives cycle types `(14)`, `(13)(1)`, and
  `(11)(2)(1)` at the unramified primes 7, 127, and 53.  Among all 63
  transitive degree-14 groups in GAP's TransGrp library, those three cycle
  types leave only `14T63 = S14`.
- Each of the fourteen small four-branch components has all 48 of its
  `2A` boundary occurrences in one of the fourteen unordered three-point
  class pairs, and every pair occurs once.  The resulting component-to-pair
  map is a bijection.
- Applying the already certified complex-conjugation permutation to the
  three-point labels transports that bijection to exactly
  `(1 12)(2 11)(4 13)(5 9)(7 10)(8 14)`, with components 3 and 6 fixed,
  matching Test 0056 independently.

Test 0097 subsequently certifies the `S14` result and the finite bijection.
Its convention audit also finds that the cited Cau--Seguin theorem assumes
product-one degeneration blocks and unramified nodes, whereas this incidence
uses a ramified order-2 node.  A suitable ramified-node equivariance lemma
would put all fourteen small four-branch components in one Galois orbit and
rule out a `Q`-defined component in this particular family, but that
implication remains conditional and is not folded into Test 0095.

Test 0098 subsequently supplies that ramified-node lemma from the general
pointed admissible-cover gluing construction and audits the quotient
conventions on a standard adjacent-split subset.  The conditional conclusion
is now discharged there: all fourteen small components form one Galois orbit.

## Path forward

1. Completed in Test 0097: an exact, independently replayable `S14`
   certificate using modular factorization and GAP identification.
2. Completed in Test 0097: verifier checks for the component-to-pair
   bijection and complex-conjugation compatibility.
3. Completed in Test 0098: source the ramified-node boundary transfer in the
   exact marked, inner, and full conventions used by the data.
4. In parallel, reconcile Seguin's explicit marked construction with the
   existing inner components and continue acquiring König's explicit
   artifacts.
5. Keep independent review of tests 0091--0095 open.
6. Publish the compact 8A negative certificate for external review before
   committing to the next long search.

The 5A machinery remains valuable reusable search engineering.  On the
current evidence, however, it ranks below the 8A transfer calculation for a
direct `M23/Q` result.

## Primary theorem references

- Orlando Cau, with the component Galois-equivariance result stated as
  Théorème 3.2:
  [*Delta-composantes des espaces de modules de revêtements*](https://www.numdam.org/item/10.5802/jtnb.811.pdf).
- Béranger Seguin restates the relevant component action as Theorem 3.1:
  [*Fields of definition of components of Hurwitz spaces*](https://arxiv.org/pdf/2303.05903).

## Scope

This test is a strategy gate based on adversarial review and bounded
feasibility probes.  Test 0097 certifies `S14` and the boundary bijection;
Test 0098 later certifies the ramified-node transfer theorem and resulting
four-branch orbit claim.
