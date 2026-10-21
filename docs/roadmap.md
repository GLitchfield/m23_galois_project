# Project roadmap

This document records the completed milestones and their evidence. The project
has been inactive since 2026-08-01. The later four-branch arithmetic work
produced the finished negative results summarized in the
[README](../README.md); its detailed record is in tests 0056--0151 and the
[Wayfinder map](wayfinder/map.md).

## Milestone 0: reproducible baseline

- Record the required GAP packages and verify the local environment.
- Maintain a pinned Lean/mathlib project for kernel-checked algebra and compact
  certificates, with explicit axiom and trust-boundary audits.
- Maintain a provenance-recording, evidence-packet-only Claude/Codex review
  harness for adversarial criticism. Treat its output as advisory and route
  every substantive objection back to literature, Lean, or an independently
  reproducible computation.
- Reproduce the checked-in basic `M23` and degree-23 transitive-group data.
- Establish Git conventions.

## Milestone 1: orientation and independent recomputation

- Treat Häfner's 2022 arXiv preprint as an external numerical target, not the
  theoretical foundation; ground Nielsen-class and braid claims in Matzat,
  Völklein, Malle--Matzat, and Magaard--Shpectorov--Völklein.
- Independently recompute the preprint's class-vector counts and known orbit
  rows from canonical group data.
- Fix a documented correspondence between GAP, ATLAS, and paper class names.
- Convert external reference results into machine-readable test fixtures, with
  their source status retained.
- Reproduced the complete 84-element `(14A,2A,2A,2A)` pure braid orbit and its
  reported genus-0 symmetry action as the first end-to-end regression case.
- Reproduced the companion 90-element `(15A,2A,2A,2A)` orbit and factored both
  quadratic-field cases through a shared fixed-first-coordinate engine.
- Reproduced the rational `(8A,8A,2A)` count and its 84 length-2, 28 length-6,
  and 14 length-12 derived orbits in `(8A)^4`.
- Lean now proves the project Hurwitz convention's product, inverse, braid,
  conjugation, and generated-subgroup formulas over arbitrary groups, together
  with the product and involution formulas used for complex conjugation.
- Reproduced the complete 2,456-element `(4A,4A,2A,2A)` orbit with pure genus
  447 and symmetric genus 169.

## Milestone 2: braid-orbit engine

- Implement Nielsen-tuple validation and Hurwitz braid actions.
- Validate against small published examples and completed `M23` cases.
- Add deterministic canonicalization, checkpointing, and shard definitions.
- Implemented and regression-tested invariant centralizer-orbit shards,
  independent checkpoint verification, safe resume, and certified merge for
  `(C,C,2A,2A)`.
- Completed and deeply certified the 30,400-class `(5A,5A,2A,2A)` bridge,
  reproducing pure genus 5,223 and symmetric genus 2,071.
- Completed and deeply certified the 72,528-class `(6A,6A,2A,2A)` bridge,
  reproducing pure genus 15,125 and symmetric genus 6,065.
- Completed and deeply certified the 198,488-class `(8A,8A,2A,2A)` bridge,
  reproducing pure genus 41,277 and symmetric genus 16,617.

## Milestone 3: bounded symmetric searches (partly completed)

- Reproduced the bridge-forced `(5A)^4` action: three pure components of size
  30,400 and one symmetric component of size 91,200, with the genera reported
  in the 2022 preprint. This construction does not certify `(5A)^4`
  exhaustiveness.
- Completed the exact bounded search `B4((4A)^4,2500)` over all 7,928,185
  macroblocks. The immutable final ledger has exact certificate-order replay,
  covers every generating vertex in the exceptional identity-product block,
  and contains exactly three closed components, each independently
  re-enumerated as 2,456 inner classes; all other components have a
  2,501-class connected witness. Test 0054 records the correction that the
  nonidentity scan alone left 4,476 generating identity vertices uncovered.
- Ported the GAP coordinate pipeline to a C++ backend (tests 0024--0055):
  versioned GAP-to-C++ checkpoints of the 45.8 MB 4A and 131.4 MB 5A global
  normalization layers, lazy per-block refinement, full-cutoff walks that
  reproduce GAP's 261-vertex 4A overflow witness and complete 5,498-vertex 5A
  component, crash-safe SQLite ownership with deterministic shards and exact
  strict-prefix replay, and an independently implemented GAP audit. A
  10,000-block four-worker rehearsal projects about 39.4 scan days for the full
  5A census. A matched eight-worker comparison gives only a 1.18-fold scan
  speedup because the shared SQLite writer serializes certificate-heavy
  blocks, and a queued single-writer variant is 7.4--10.5 percent slower.
- Reduced fixed-first 5A generation exactly to 14 maximal-subgroup incidence
  bits. GAP's direct generation test and the mask predicate agree on all 3,089
  first-block representatives across 16 nonidentity product classes; the full
  native table is a 1.3 MB payload aligned with the coordinate checkpoint.
- An exact RTX 4080 braid-image batch agrees bit for bit with CPU/GAP fixtures
  (tests 0039 and 0041). It was not integrated into a ledger.
- The exhaustive `(5A)^4`, `(6A)^4`, and `(8A)^4` searches were not run.
