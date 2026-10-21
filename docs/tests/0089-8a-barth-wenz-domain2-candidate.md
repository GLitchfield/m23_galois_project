# Test 0089: certified domain-2 numerical Belyi candidate

## Question

Does the second Barth--Wenz fundamental domain produce a nondegenerate
solution of the normalized class-1 8A Belyi root equations under the same
predeclared gates used for domain 1?

## MATLAB result intake

The authenticated MATLAB Online run used the domain-2 bundle prepared at
revision `b9cf11876c22abd158d079b196d898e7bcbe8973`. The returned archive has
SHA-256
`5a9e1b31d243b8e3eaebf8636adfa2ac386e00757fe6b39eafe2e4612108c918`.
It records MATLAB R2026a Update 4, SC Toolbox 3.1.3, the pinned
Barth--Wenz source hash, and domain index 2.

The run completed with SC-map accuracy `1.8412309769781973e-8`.
Independent intake recovered all prescribed cycle partitions, found maximum
spread `7.65e-15` inside a prescribed cycle, and found the closest distinct
roots `34,225` times farther apart than the SC-map error.

## Chart selection and direct Newton

All six placements of `(4,2,1)` at `(0,1,infinity)` were evaluated with the
correct chart-aware equations. Normalization `(1,4,2)` passed the frozen seed
gates with relative residual `0.1592184`, equilibrated condition `1.07e8`,
and minimum all-fibre chordal separation above `1e-8`.

The ordinary 100-step damped Newton gate was rejected. It ended with relative
residual `3.54e-9` and approached an `F`--`Q` collision at distance
`9.60e-14`. This negative result is retained separately and was not promoted
to a candidate.

## Seven-factor continuation

One strong saturated path used:

- normalization `(1,4,2)`;
- gamma angle `1.4`;
- zero regularization;
- the existing 800-step tracker bound;
- Julia 1.12.6; and
- HomotopyContinuation.jl 2.21.0.

The path reached `t=0` with return code `success` after 28 accepted steps and
no rejected steps. Its recorded diagnostics were:

| diagnostic | value |
| --- | ---: |
| path residual | `6.21e-16` |
| maximum coefficient residual | `7.49e-14` |
| minimum all-fibre chordal separation | `0.00155434` |
| minimum `F`--`Q` separation | `0.00155434` |
| scaled saturated Jacobian condition | `5.99e16` |
| interval certification | `true` |

HomotopyContinuation's certification applies to the represented numerical
square system. It is strong local existence evidence, but it is not an exact
number-field certificate.

## Independent validation

`scripts/check_barth_wenz_candidate.py` reads the committed endpoint without
using the Julia residual implementation. It:

- checks the endpoint's seed and revision hashes;
- evaluates all 23 coefficient equations with the independent Python code;
- checks every within- and cross-fibre separation;
- reconstructs all seven saturation factors and their scaled inverse
  equations; and
- requires the recorded successful path and `certified=true` verdict.

The independent computation obtains relative residual `3.17287e-16`,
equilibrated root-system condition `6.12e8`, and the same minimum separation
`0.00155434`.

## Result

Pass as a **certified, nondegenerate numerical solution of the represented
class-1 root system**. This is the first local numerical endpoint in the
project to pass the coefficient, collision, saturation, target-parameter, and
interval-certification gates.

It is not yet an exact Belyi map and does not by itself prove monodromy `M23`
or an `M23` realization over `Q`. The next gate is high-precision refinement,
followed by algebraic recognition and exact independent ramification and
monodromy verification. Those checks must fail closed rather than infer exact
arithmetic from double-precision coordinates.

Test 0090 subsequently completed the high-precision and numerical-monodromy
parts of that gate: the coefficients refine to 4096 bits, and stable loop
lifting generates `M23` and uniquely matches class 1. Test 0091 then completed
exact degree-28 recognition and independent exact ramification. Formally
certified exact monodromy remains separate, and none of these results is an
`M23/Q` realization.

## Reproduction

Given the ignored MATLAB result archive:

```sh
python3 scripts/intake_barth_wenz_matlab_result.py \
  /tmp/m23-matlab-domain2-result \
  --environment \
    /tmp/m23-matlab-domain2-result/matlab_environment_domain2.txt \
  --result-archive \
    runs/8a-barth-wenz-matlab-class1-domain2-result-20260723.zip \
  --domain-index 2 \
  --output /tmp/m23_8a_barth_wenz_class1_domain2_dessin.tsv
python3 scripts/check_barth_wenz_matlab_result.py \
  /tmp/m23_8a_barth_wenz_class1_domain2_dessin.tsv
python3 scripts/prepare_barth_wenz_root_seed.py \
  --dessin "$PWD/data/derived/m23_8a_barth_wenz_class1_domain2_dessin.tsv" \
  --census-output /tmp/domain2-chart-census.tsv \
  --seed-output /tmp/domain2-root-seed.tsv
julia --project=julia/8a_belyi \
  julia/8a_belyi/run_root_saturated_continuation.jl \
  data/derived/m23_8a_barth_wenz_domain2_root_seed.tsv \
  1 1,4,2 1.4 0 /tmp/domain2-certified strong
python3 scripts/check_barth_wenz_candidate.py \
  /tmp/domain2-certified-path1.tsv
```

## Evidence

- `data/derived/m23_8a_barth_wenz_class1_domain2_dessin.tsv`;
- `data/derived/m23_8a_barth_wenz_domain2_root_chart_census.tsv`;
- `data/derived/m23_8a_barth_wenz_domain2_root_seed.tsv`;
- `data/derived/m23_8a_barth_wenz_domain2_newton_summary.tsv`;
- `data/derived/m23_8a_barth_wenz_domain2_certified_endpoint-path1.tsv`;
- `scripts/intake_barth_wenz_matlab_result.py`;
- `scripts/check_barth_wenz_matlab_result.py`;
- `scripts/check_barth_wenz_candidate.py`; and
- `julia/8a_belyi/run_root_saturated_continuation.jl`.
