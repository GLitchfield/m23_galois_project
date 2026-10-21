# Experimental 8A continuation environment

This isolated Julia project tracks deterministic seeds for the reduced and
full coefficient `(8A,8A,2A)` Belyi systems. It uses a locked
`HomotopyContinuation.jl` environment and does not alter the main GAP/Lean
toolchain.

Instantiate and test it with:

```sh
julia --project=julia/8a_belyi -e 'using Pkg; Pkg.instantiate()'
julia --project=julia/8a_belyi julia/8a_belyi/test_continuation.jl
```

Generate the six distinguished-point charts from the two-refinement circle
packing and run eight deterministic gamma paths in one chart with:

```sh
python3 -m pip install -r requirements-8a-belyi-pilot.txt
python3 scripts/pilot_8a_belyi_circle_pack.py \
  --refinements 2 --seed-dir /tmp/m23_8a_charts --seed-only
julia --project=julia/8a_belyi julia/8a_belyi/run_continuation.jl \
  /tmp/m23_8a_charts/seed_1_4_2.tsv 8 1,4,2
```

`run_continuation.jl` retains the singular 16-variable elimination experiment.
For numerical continuation, use the nonsingular root-free coefficient system:

```sh
julia --project=julia/8a_belyi julia/8a_belyi/run_full_continuation.jl \
  /tmp/m23_8a_charts/seed_4_2_1.tsv 8 4,2,1 0 0.7 0 projective_alpha
```

The full runner supports `affine`, `projective`, `affine_alpha`, and
`projective_alpha` modes.  The last two add the saturation equation
`alpha * inverse_alpha = 1`; projective modes homogenize every equation and
track on a deterministic random affine chart of projective space.  An optional
final argument is an endpoint-file prefix.

The labeled-root runner imposes all five nondegeneracy factors at once:

```sh
python3 scripts/pilot_8a_belyi_circle_pack.py \
  --refinements 2 --root-seed-dir /tmp/m23_8a_root_charts --seed-only
julia --project=julia/8a_belyi \
  julia/8a_belyi/run_root_saturated_continuation.jl \
  /tmp/m23_8a_root_charts/root_seed_4_2_1.tsv 4 4,2,1
```

The runners use coordinate and Jacobian equilibration, a dessin-centered
residual-shift start system, deterministic complex gamma values,
mixed-precision path tracking, and post-path factor-separation diagnostics. A
low homotopy residual is not an accepted Belyi candidate: the path must reach a
successful endpoint, pass interval certification, remain nondegenerate, and
later pass exact ramification and monodromy verification.

The test suite also regression-checks sequential parameter waypoints,
polynomial-system monodromy with certified duplicate detection, and transport
to a new parameter fibre. These are software-capability checks only. The
documented project inputs do not yet identify a solved, nondegenerate Belyi
fibre connected to the 8A target by a mathematical parameter family. In
particular, HomotopyContinuation's monodromy solver is not a certificate of a
Belyi map's permutation monodromy; see test 0074.
