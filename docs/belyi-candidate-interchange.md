# Exact Belyi candidate interchange

`data/schema/belyi_candidate_v1.schema.json` defines the portable boundary
between any equation producer and the local exact verifier. The producer may
be Magma, Julia, another CAS, or an external collaborator. The format does not
grant trust to the producer.

## Required content

A `belyi-candidate-v1` record contains:

- the problem identifier and three expected ramification partitions;
- a monic defining polynomial and power-basis generator, or `null` for `Q`;
- low-to-high exact numerator and denominator coefficients;
- a source description; and
- producer software, revision, and optional configuration.

Rational numbers are JSON integers or strings such as `"-3/5"`. A number-field
element is the low-to-high power-basis list

```json
["3", "1/2"]
```

for `3 + a/2`. Polynomial coefficient lists are also low-to-high.

For the project target, `problem.id` is
`m23-8a-8a-2a-degree23`. The verifier then requires a source class in `1..28`,
the committed inner-class dataset SHA-256, and exactly the target passport. A
different source hash or a passport supplied by the producer cannot silently
change the question being checked.

## Verification layers

`scripts/verify_belyi_candidate.py` performs these independent checks:

1. schema and target provenance;
2. monicity and power-basis coefficient shape;
3. irreducibility of the defining polynomial over `Q`, proved by the installed
   GAP rather than trusted from the producer;
4. exact numerator/denominator coprimality;
5. exact multiplicity partitions over `0`, `1`, and infinity; and
6. Riemann--Hurwitz.

Using `--skip-irreducibility-check` is diagnostic only. Its result is labeled
`diagnostic_field_unchecked`, exits with status 3, and is not an accepted
number-field candidate.

These checks still do not recover or certify the permutation monodromy of the
cover. Matching an exact map to one of the 28 source triples remains a separate
stage.

## Magma adapter

The bounded class-1 pilot prints a small marker language containing only
nested lists and rational numbers. `extract_magma_belyi_candidate.py` parses
that restricted grammar without evaluating Magma or Python expressions,
records a transcript hash, and emits the versioned JSON. The adapter rejects
missing or duplicate markers and any exact result for which Magma did not
report its own ramification sanity check.

The serialization fixture passed on the official calculator's Magma V2.29-8
runtime. Its wrapped output led the restricted parser to support balanced
multiline lists as well as single-line lists. Run the seconds-long
`magma/8a_belyi/serialization_smoke.m` fixture again on the eventual solver
host before a long external solve. A successful smoke verifies the runtime
serialization convention, not the Belyi package's exact-map attributes or the
target calculation.
