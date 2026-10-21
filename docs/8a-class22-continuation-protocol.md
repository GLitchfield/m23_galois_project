# Predeclared class-22 continuation protocol

> **Superseded.** Test 0087 corrected a Möbius-normalization mismatch in the
> Python seed diagnostics. The corrected test 0078 rejects this chart, so this
> protocol is retained only to explain the historical test-0080 run and must
> not authorize another run.

Under the original test-0078 verdict, exactly one bounded continuation was
authorized with:

- certified class: 22;
- cyclic rotation: 1;
- normalization: `(2,1,4)`;
- seed: two-refinement circle packing;
- system: the existing five-factor saturated labeled-root system;
- gamma angle: `0`;
- regularization: `1e-4`;
- paths: 1; and
- tracker/endgame bounds: exactly those committed in
  `julia/8a_belyi/run_root_saturated_continuation.jl`.

The endpoint is a candidate only if the tracker returns success, coefficient
residual is below `1e-10`, `|alpha|` and every chordal separation exceed
`1e-8`, all inverse coordinates are finite, and interval certification passes.
Any other outcome is recorded once without a phase or regularization sweep.

A successful numerical endpoint still requires independent exact
ramification and monodromy verification. A failure excludes only this selected
seed, chart, path, and homotopy construction; it does not exclude the class-22
cover or the degree-23 passport.
