# Test 0080: bounded class-22 saturated continuation

## Status after normalization audit

The computation documented here was run as stated, but test 0087 later found
that test 0078's authorization premise used a mismatched Python normalization.
The corrected transfer gate rejects the selected chart. This negative run is
therefore retained as operational history, not as evidence about a seed
selected by the corrected equations.

## Question

Does the single class-22 chart admitted by test 0078 produce a certified Belyi
endpoint under the predeclared continuation protocol?

## Method

Revision `74cf81e` froze class 22, rotation 1, normalization `(2,1,4)`, two
circle-packing refinements, gamma angle zero, regularization `1e-4`, one path,
and the existing tracker bounds. The first launch exposed a chart-padding bug
before path tracking began. It was not counted as the authorized path.

Revision `e9db740` padded the missing high coefficients when the normalized
point at infinity has multiplicity 2 or 4 and added agreement tests for all six
charts. After the full suite passed, the same predeclared path was run once.

## Result

No candidate. The tracker exhausted its fixed 800 accepted-step bound with
return code `terminated_max_steps` at homotopy parameter `1.99e-6`. The path
residual was `8.93e-12`, but the unscaled coefficient residual was still
`7.21e-4`, far above the `1e-10` acceptance threshold, so certification was
correctly skipped. The endpoint Jacobian condition estimate was `4.50e33`.

This is not the same failure seen in the earlier class-1 paths. The endpoint
root norm was `61.9`, inverse norm `1.09`, `|alpha|=1.09`, and minimum chordal
separation `0.00375`; the tracker did not report infinity and the visible root
separation gates remained comfortably nonzero. Instead, the bounded path
became extremely ill-conditioned and failed to reach a sufficiently accurate
target endpoint before the step limit.

Even under its historical premise, the result excluded only that seed, chart,
gamma, regularization, homotopy, and step bound. It says nothing against
existence of the class-22 cover and does not replace the specialized Magma
computation.

## Evidence

- `docs/8a-class22-continuation-protocol.md`;
- `data/derived/m23_8a_belyi_seed_selection.tsv`;
- `data/derived/m23_8a_class22_saturated_continuation.tsv`;
- `julia/8a_belyi/run_root_saturated_continuation.jl`; and
- `julia/8a_belyi/test_continuation.jl`.
