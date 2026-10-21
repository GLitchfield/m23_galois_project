# Test 0072: projective coefficient continuation for the 8A Belyi target

## Question

Can a root-free coefficient formulation, multiple normalization charts,
projective path tracking, and explicit nonzero-`alpha` saturation turn the
class-1 circle-packing seed into a certified nondegenerate Belyi map?

## Formulation

The 16-variable remainder system from test 0068 is useful for elimination but
is intrinsically singular at every intended solution: at `H = U^2 V`, a
first-order change in `U` does not change `H mod U`.  The new square system
therefore retains the seven coefficients of the monic degree-7 factor `V` and
uses all 23 coefficient equations of

```text
P + F = U^2 V.
```

This keeps the eight roots of `U` unlabeled while restoring first-order
sensitivity.  An exact degenerate fixture independently checks the generated
coefficient identity.  The runner alternates row/column equilibration, starts
from the exact residual-shift system centered at the dessin seed, and supports
both affine and homogeneous projective tracking.  The saturated modes append
`alpha * inverse_alpha = 1`.

Six placements of the distinguished ramification points at `0`, `1`, and
infinity were generated deterministically.  The `(4,2,1)` chart was best
conditioned at the seed (`4.66e5`); the alternatives ranged from about `1e9`
to `1e18`, so the recorded ensemble uses `(4,2,1)`.

## Result

No path passed the acceptance gates.  The most informative outcomes were:

| formulation | numerical observation | rejection reason |
|---|---|---|
| affine coefficient | very small coefficient residual, singular endpoint | boundary solution, not certifiable |
| projective coefficient | homogenizer stayed finite while `abs(alpha)` fell to `4.63e-3` | approaches `alpha = 0` |
| affine `alpha` saturation | `abs(alpha)=1.60e-3`, `abs(inverse_alpha)=626` | the forbidden boundary moved to affine infinity |
| projective `alpha` saturation | homogenizer fell to `3.10e-2` | the same escape appears on the projective boundary |
| saturated phase `2.1` | `P`--`F` separation fell to `1.21e-5` | a different collision boundary |

Several paths attained coefficient residuals below `1e-12` while remaining
geometrically separated at the reported finite iterate.  None returned
success, none had a full-rank endpoint Jacobian, and interval certification
rejected or was correctly skipped.  A small residual is therefore not a Belyi
candidate here.

This is a negative solver result, not a nonexistence result. By the classical
Riemann existence/branch-cycle theorem, the exact permutation triple still
guarantees the complex cover; that theorem is external established mathematics
and not currently Lean-formalized. The experiment locates
the present obstruction more precisely: straight residual-shift paths are
attracted to the boundary of the passport even after projectivization, and
saturating only `alpha` merely redirects them to infinity or to another fibre
collision.

## Reproduction

Generate the seed and run a recorded path with:

```sh
PYTHONPATH=/tmp/m23_8a_python_deps python3 \
  scripts/pilot_8a_belyi_circle_pack.py \
  --refinements 2 --seed-dir /tmp/m23_8a_full_charts --seed-only

julia --project=julia/8a_belyi \
  julia/8a_belyi/run_full_continuation.jl \
  /tmp/m23_8a_full_charts/seed_4_2_1.tsv \
  1 4,2,1 0 2.1 1e-4 projective_alpha /tmp/m23_8a_path
```

The recorded calculation used Julia 1.12.6,
HomotopyContinuation.jl 2.21.0, code revision
`43da20118c4f76b12337b6068fb048f59c164103`, and the seed and source hashes in
the TSV.  Temporary seeds and endpoints are intentionally not committed.

## Consequence

The next local experiment should impose all five nondegeneracy factors from
test 0071 simultaneously: nonzero `alpha`, distinct `P`, `F`, and `Q` fibres,
and disjoint `P`/`F` fibres.  The existing 23-root coordinate formulation has
these factors explicitly and is the clearest place to combine full saturation
with the projective tracker.  Any successful numerical point must still pass
the exact verifier and an independent monodromy certificate.  The specialized
Magma Belyi package remains the established external route.

## Evidence

- `julia/8a_belyi/M23Belyi8A.jl`;
- `julia/8a_belyi/run_full_continuation.jl`;
- `julia/8a_belyi/test_continuation.jl`; and
- `data/derived/m23_8a_coefficient_continuation_pilot.tsv`.
