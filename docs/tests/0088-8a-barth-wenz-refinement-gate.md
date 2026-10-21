# Test 0088: Normalization and bounded refinement of the MATLAB dessin

## Question

Can the validated domain-1 Barth--Wenz dessin be translated into the
23-variable root system and refined to a nondegenerate numerical solution?

## Six-chart translation

`scripts/prepare_barth_wenz_root_seed.py` maps the unique zero-fibre points of
multiplicities `(4,2,1)` to `(0,1,infinity)` in all six orders. It assigns:

- the zero fibre to `P`;
- the pole fibre to `F`;
- the involution fibre to `Q`; and
- the scalar `alpha` by complex least squares across all 23 coefficient
  equations.

The predeclared joint gates require relative residual below `0.25`,
equilibrated Jacobian condition below `1e16`, and every within- and
cross-fibre chordal separation above `1e-8`. Only `(1,4,2)` passes, with:

| diagnostic | value |
| --- | ---: |
| relative residual | `0.13192220420151926` |
| equilibrated condition | `1.5235994898559201e8` |
| minimum all-fibre separation | `0.001631582852079423` |

The lower-residual `(4,1,2)` chart is rejected because its condition estimate
is `2.04e17`.

## Bounded direct Newton result

The selected seed underwent at most 100 damped Newton iterations. It accepted
88 steps and reduced the relative residual to `7.3676e-12`. That apparent
success is rejected: an `F` root and a `Q` root approached to chordal distance
`2.5023e-14`.

This exposed a numerical-validation distinction. For an exact solution,
coprimality of `P` and `F` plus `P+F=Q` implies separation from `Q`. For an
approximate endpoint, that implication cannot be used before the residual is
zero. The acceptance gate now checks all three cross-fibre pairs explicitly.

## Strong saturated continuation

The Julia system was extended from five to seven saturation factors by adding
explicit `P`--`Q` and `F`--`Q` products. The extension is algebraically
redundant at an exact solution but prevents the approximate collision from
being silently accepted.

One bounded strong path used normalization `(1,4,2)`, gamma angle `1.4`, zero
regularization, 800-step tracker bounds, Julia 1.12.6, and
HomotopyContinuation 2.21.0. It returned `at_infinity` with:

| diagnostic | value |
| --- | ---: |
| homotopy parameter | `3.3878e-9` |
| inverse norm | `7.5494e4` |
| coefficient residual | `4.7016e-8` |
| `F`--`Q` separation | `4.9154e-9` |
| endpoint Jacobian condition | `3.9385e28` |

Certification was correctly skipped. The rejected endpoint is not committed;
its SHA-256 is recorded in the compact result ledger.

## Result

Domain 1 supplies a useful, reproducible numerical seed, but neither bounded
refinement produced a nondegenerate candidate. Direct Newton enters a
cross-fibre collision, while the stronger saturated path exposes that boundary
as an infinity escape.

This is enough evidence to invoke the authors' prescribed fallback: compare
the second fundamental domain before changing tolerances, adding phase
sweeps, or scaling the search. Domain 2 is a genuinely different conformal
chart of the same permutation triple and is already packaged.

Test 0089 subsequently completed that comparison and obtained a certified,
nondegenerate numerical endpoint from domain 2. That later success does not
change the negative domain-1 result recorded here.

## Reproduction

```sh
python3 scripts/prepare_barth_wenz_root_seed.py \
  --census-output \
    data/derived/m23_8a_barth_wenz_root_chart_census.tsv \
  --seed-output data/derived/m23_8a_barth_wenz_root_seed.tsv
python3 scripts/refine_barth_wenz_root_seed.py \
  data/derived/m23_8a_barth_wenz_root_seed.tsv \
  --maximum-iterations 100 \
  --summary-output \
    data/derived/m23_8a_barth_wenz_newton_summary.tsv \
  --endpoint-output /tmp/m23_8a_barth_wenz_rejected_endpoint.tsv
julia --project=julia/8a_belyi \
  julia/8a_belyi/run_root_saturated_continuation.jl \
  data/derived/m23_8a_barth_wenz_root_seed.tsv \
  1 1,4,2 1.4 0 /tmp/8a-bw-strong strong
python3 scripts/check_barth_wenz_refinement.py
```

## Evidence

- `data/derived/m23_8a_barth_wenz_root_chart_census.tsv`;
- `data/derived/m23_8a_barth_wenz_root_seed.tsv`;
- `data/derived/m23_8a_barth_wenz_newton_summary.tsv`;
- `data/derived/m23_8a_barth_wenz_strong_continuation.tsv`;
- `scripts/prepare_barth_wenz_root_seed.py`;
- `scripts/refine_barth_wenz_root_seed.py`;
- `scripts/check_barth_wenz_refinement.py`; and
- `julia/8a_belyi/M23Belyi8ARoots.jl`.
