# Test 0092: rigorous monodromy of the exact class-1 8A Belyi map

## Question

Can the numerical loop lifting in test 0090 be replaced by a rigorous
computer-assisted proof that the exact equation from test 0091 has monodromy
`M23` in inner class 1?

## Exact input and embedding

The computation reads the versioned exact candidate, not rounded map
coefficients. Sage isolates all 28 complex embeddings of the reciprocal
degree-28 defining polynomial with complex-ball arithmetic. The embedding is
selected by the exact recovered expression for `c2` and the independently
computed 16,384-bit value. The other 22 exact coefficients are then evaluated
in that same isolated embedding.

Thus the high-precision coefficient file selects the intended conjugate; it
does not supply the coefficients used in the proof.

## Interval continuation

The two standard counterclockwise loops based at `1/2` are circles of radius
`1/2` around 0 and 1. Each loop is divided into 8,192 closed arcs. Rigorous
trigonometric interval evaluation encloses every point of an arc, rather than
sampling finitely many parameter values.

For each of the 23 roots at an arc midpoint, the certifier uses the affine
predictor

```text
x(z) = x0 + s (z - z0) + e,
s = Q(x0) / (P'(x0) - z0 Q'(x0)).
```

It evaluates the exact algebraic coefficients and all transcendental path
bounds in Sage's Arb-backed ball fields. A centered Taylor expansion avoids
discarding the cancellation built into the predictor. For an interval error
box `E`, the program encloses the correction map and verifies both:

```text
T_z(E) is strictly contained in E for every z in the arc,
sup |dT_z/de| < 1.
```

The contraction theorem therefore gives one and only one root in each
predicted box for every parameter on the complete arc. The 23 root tubes are
pairwise disjoint. At every shared endpoint, interval overlap gives a unique
bijective matching to the next segment. Chaining those matchings returns a
certified permutation of the base fibre.

This argument is stronger than mesh stability: a root cannot leave its tube,
collide with another root, or change the reported matching between sampled
points.

## Result

All 16,384 arcs and their 376,832 root-tube certificates pass. The worst
bounds are:

| loop | maximum tube diameter | maximum contraction bound | cycle lengths |
| --- | ---: | ---: | --- |
| around 0 | `0.0031208359214360826` | `0.54037416540086269` | `(8,8,4,2,1)` |
| around 1 | `0.0031043748385854997` | `0.5380390826612711` | `(8,8,4,2,1)` |

The inverse product has cycle partition `(2^8,1^7)`. The independent Python
checker asks GAP to prove that the two finite permutations:

- generate a group of order `10,200,960`, with structure description `M23`;
- have trivial centralizer in the degree-23 symmetric group;
- satisfy product one with the recorded infinity permutation; and
- match exactly class 1 of the complete 28-row inner-class ledger.

The certified permutations agree with the earlier high-precision numerical
continuation up to simultaneous relabeling of the base fibre.

## Scope and trust boundary

Pass as a rigorous interval certificate for the monodromy of the selected
complex embedding of the exact Belyi equation. Combined with test 0091, this
establishes an exact degree-23 Belyi cover over a degree-28 number field whose
geometric monodromy is `M23`, in inner class 1.

This is a computer-assisted proof whose analytic trust base includes SageMath
10.9, Arb ball arithmetic, the certifier implementation, and GAP 4.12.1. It is
not presently kernel-checked in Lean. It is also not an `M23/Q` realization:
the coefficient field has degree 28, and the remaining arithmetic question is
the Galois action/descent of this orbit.

## Reproduction

The full run takes about seven minutes on the development machine:

```sh
./scripts/run-8a-sage.sh --python \
  scripts/certify_8a_interval_monodromy.sage \
  data/derived/m23_8a_belyi_class1_exact_candidate.json \
  data/derived/m23_8a_belyi_class1_number_field_recovery.tsv \
  data/derived/m23_8a_belyi_class1_high_precision_coefficients_16384.tsv \
  --precision-bits 512 \
  --steps-per-loop 8192 \
  --output /tmp/m23_8a_interval_monodromy.tsv

python3 scripts/check_8a_interval_monodromy.py \
  /tmp/m23_8a_interval_monodromy.tsv
```

The committed evidence is
`data/derived/m23_8a_belyi_class1_interval_monodromy.tsv`. Its metadata records
the producer revision, all three input paths and hashes, Sage version,
precision, path convention, subdivision count, and proof conditions.
