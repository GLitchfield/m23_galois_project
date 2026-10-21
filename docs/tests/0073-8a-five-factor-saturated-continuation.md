# Test 0073: five-factor saturated continuation for the 8A Belyi target

## Question

Does excluding all known degenerate passport boundaries simultaneously allow a
dessin-centered continuation path to reach the class-1 `(8A,8A,2A)` Belyi map?

## Method

The test returns to the labeled 23-root formulation: `alpha`, two roots over
each of the first two branch fibres, three remaining roots over the second
fibre, eight double roots over the third fibre, and seven simple roots there.
Its 23 coefficient equations are independently cross-checked against the
root-free coefficient system from test 0072.

Five inverse variables append five saturation equations.  They require:

1. nonzero `alpha`;
2. distinct roots in the `P` fibre;
3. distinct roots in the `F` fibre;
4. distinct roots in the `Q` fibre; and
5. disjoint `P` and `F` fibres.

The raw saturation factors at the circle-packing seed range up to
`5.67e119`, so each equation is normalized by its seed value.  After combined
row/column equilibration, the 28-by-28 seed Jacobian has condition about
`2.83e7`.  The start system is the same exact residual-shift construction used
in test 0072.  Four deterministic phases at regularization `1e-4` and two
additional regularizations at phase zero test whether the result is a tuning
artifact.

## Result

All six paths were classified `at_infinity`.  The phase ensemble stopped at
values of `t` between `8.09e-3` and `1.13e-6`; changing regularization from
`1e-4` to `1` delayed one escape to `5.06e-11` but did not produce a finite
endpoint.  The largest scaled inverse coordinate ranged from `747` to
`1.39e10`.

This is a useful improvement over the earlier false small-residual endpoints:
the fully saturated system refuses every known collision boundary and reports
the path escape directly.  It is not evidence against existence of the cover.
It shows that the tested straight residual-shift homotopy from this
circle-packing seed has no finite continuation across the sampled phases and
regularizations.

No row passes the acceptance gates, so no coefficient recognition, exact
ramification check, or monodromy claim is attempted.

## Reproduction

```sh
PYTHONPATH=/tmp/m23_8a_python_deps python3 \
  scripts/pilot_8a_belyi_circle_pack.py \
  --refinements 2 --root-seed-dir /tmp/m23_8a_root_charts --seed-only

julia --project=julia/8a_belyi \
  julia/8a_belyi/run_root_saturated_continuation.jl \
  /tmp/m23_8a_root_charts/root_seed_4_2_1.tsv \
  1 4,2,1 0.7 1e-4 /tmp/m23_8a_root_path
```

The recorded calculation used Julia 1.12.6,
HomotopyContinuation.jl 2.21.0, code revision
`2b250439ee5e4ff65ba9d9a28404a147507e6bf0`, and the hashes in the TSV.
Temporary root seeds and endpoints are intentionally not committed.

## Consequence

Further phase or regularization sweeps of this exact class-1, `(4,2,1)` chart,
two-refinement seed, and straight residual-shift construction have low value.
Test 0074 confirms that the software supports parameter homotopy and
polynomial-system monodromy, but its documented inventory identifies no
genuinely related solved Belyi start. Projective compactification of the fully
saturated system can explain which infinity component receives each path, but
by itself cannot turn those paths into finite target solutions. The specialized Magma Belyi solver
remains the principal established comparison.

## Evidence

- `julia/8a_belyi/M23Belyi8ARoots.jl`;
- `julia/8a_belyi/run_root_saturated_continuation.jl`;
- `julia/8a_belyi/test_continuation.jl`; and
- `data/derived/m23_8a_root_saturated_continuation_pilot.tsv`.
