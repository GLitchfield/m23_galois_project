# Test 0069: exact candidate verifier for the 8A Belyi target

## Question

Can candidate equations returned by Magma, a numerical recognizer, or an
external collaborator be checked locally without trusting the solver that
produced them?

## Method

`verify_belyi_candidate.py` accepts a rational function `P/Q` in JSON. Its
coefficients may be rational numbers or power-basis elements of a number field
defined by a monic polynomial. The versioned public format is specified by
`data/schema/belyi_candidate_v1.schema.json`; legacy flat fixtures remain
accepted for regression compatibility. The verifier performs exact rational
arithmetic and checks:

1. target provenance and schema shape;
2. irreducibility of a nontrivial field polynomial over `Q`, independently
   proved by the installed GAP;
3. `P` and `Q` are nonzero and coprime;
4. the map has the expected degree;
5. the multiplicity partitions over `0`, `1`, and infinity, including a source
   point at infinity when polynomial degrees differ;
6. the total ramification satisfies Riemann--Hurwitz.

The multiplicities are obtained by exact polynomial gcd and squarefree
decomposition over the coefficient field; no numerical root clustering or
factorization is used.  Tests cover rational maps `x^2` and `4x(1-x)`, a map
over `Q(sqrt(2))`, a wrong passport, and a numerator/denominator collision.

Candidate JSON uses low-to-high coefficient order. A coefficient such as
`[3, "1/2"]` means `3 + a/2`, where `a` is the power-basis generator:

```json
{
  "field_polynomial": ["-2", "0", "1"],
  "numerator": ["2", ["0", "-2"], "1"],
  "denominator": ["1"]
}
```

The example above is the legacy compact form. New external results should use
the versioned interchange documented in `docs/belyi-candidate-interchange.md`.
For the project problem, the versioned form fixes the target partitions, class
range, and certificate dataset hash rather than accepting them solely from the
producer.

## Boundary

This verifies an exact Belyi ramification claim, not its monodromy group.  A
degree-23 map with the same cycle passport can have monodromy outside `M23`.
Acceptance as one of the 28 target maps therefore also requires certified
monodromy or an explicit path back to one of the committed permutation
triples. The verifier now invokes GAP for the field-polynomial irreducibility
proof. `--skip-irreducibility-check` is retained only to diagnose an imported
record; it returns `diagnostic_field_unchecked` with process status 3, not an
accepted candidate. Missing or malformed GAP verdict output also fails closed
rather than being conflated with a mathematical reducibility verdict.

## Reproduction

```sh
python3 scripts/test_verify_belyi_candidate.py
python3 scripts/verify_belyi_candidate.py candidate.json
```

## Result

All positive and negative regression fixtures pass, including reducible-field
rejection, missing-GAP-verdict rejection, a nonzero diagnostic-bypass status,
target-provenance rejection, and the versioned schema. The project can ingest
exact candidate coefficients independently of their producer while keeping
field, ramification, and monodromy claims separate.
