# Test 0011: homogeneous pair blocks and bounded witnesses

## Question

Can the homogeneous tuple space be partitioned into an exact, compact outer
enumeration that supports both closed bounded components and independently
replayable overflow witnesses?

## Method

Enumerate `C_G(c) backslash M23 / C_G(c)` for target classes 4A and 5A. Normalize
each ordered pair to a fixed representative of its product class and record its
stabilizer. Define all pair-pair macroblocks symbolically by matching inverse
product classes, then materialize selected blocks through relative-centralizer
double cosets.

Independently reconstruct all normalized pair orbits and check their weighted
coverage against `|C|^2`. On 4A, run capped pure-braid traversal from a known
translated seed and from a generic generating macroblock seed.

## Result

- 4A: 10,099 pair orbits and 7,928,185 symbolic macroblocks;
- 5A: 45,344 pair orbits and 161,177,452 symbolic macroblocks;
- complete pair-orbit coverage independently verified for both targets;
- sampled cyclic-product macroblocks materialize the predicted number of inner
  classes through relative double cosets;
- the translated 4A seed closes at exactly 2,456 classes;
- the generic 4A seed reaches exactly 2,501 classes at bound 2,500;
- a generic 5A seed reaches exactly 251 classes at Häfner's earlier bound 250.

This passes the pair-partition and bounded-witness infrastructure test. It is
not yet the complete 4A macroblock traversal; that is the next certification
gate.

## Reproducibility record

- baseline revision: `0e4e402`; implementation is the commit containing this
  note;
- GAP 4.12.1, AtlasRep 2.1.8, CTblLib 1.3.7;
- inputs: M23's natural degree-23 action and its unique classes of orders 4
  and 5;
- provenance: project-owned double-coset enumeration and independent orbit
  reconstruction; MapClass 1.4.6 was inspected as a comparison implementation
  but is not a runtime dependency and no source was copied.

## Artifacts

- `data/reference/m23_homogeneous_pair_block_census.tsv`
- operational full pair checkpoints under ignored `runs/`
