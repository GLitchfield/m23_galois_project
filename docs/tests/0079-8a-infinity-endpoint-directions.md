# Test 0079: projective audit of the six class-1 infinity endpoints

## Question

Do the six `at_infinity` outcomes from test 0073 represent one common escape
direction, and does any endpoint look like a finite near-solution hidden by a
single harmless scale?

## Method

The six paths were rerun with endpoint export at revision `4fbacc4`. Each file
records the code revision and seed SHA-256. The audit divides all 28 saturated
affine coordinates by the largest absolute coordinate and records the support
at or above one percent. This is ordinary projective normalization for
diagnosis, not a computation of a compactified solution scheme.

## Result

Five paths are overwhelmingly `inverse_q`-dominated. Their largest inverse
coordinate exceeds the largest root coordinate by factors from `1.95e6` to
`1.20e8`; after normalization, no other coordinate reaches one percent.

The `gamma=0.7`, regularization `1e-4` path is different: `alpha` is dominant,
`inverse_q/alpha=0.7908`, and several root and inverse coordinates remain in
the one-percent projective support. It is a mixed root/inverse escape rather
than the same pure inverse direction.

Thus the old label hid at least two numerical escape regimes. None is a finite
near-solution: all six tracker return codes remain `at_infinity`, and test
0073's coefficient residual, endpoint norm, and condition gates remain failed.
The dominance of `inverse_q` identifies the scaled inverse of the q-root
Vandermonde as the main carrier in five runs; it does not by itself prove a
particular component of a projective compactification.

## Evidence

- `data/derived/m23_8a_infinity_endpoint_audit.tsv`;
- `data/derived/m23_8a_root_saturated_continuation_pilot.tsv`;
- `scripts/analyze_8a_infinity_endpoints.py`;
- `scripts/test_analyze_8a_infinity_endpoints.py`; and
- `julia/8a_belyi/run_root_saturated_continuation.jl`.
