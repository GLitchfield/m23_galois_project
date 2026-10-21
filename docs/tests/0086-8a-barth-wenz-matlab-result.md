# Test 0086: Domain-1 Barth--Wenz numerical dessin for the 8A target

## Question

Does the authenticated domain-1 MATLAB run return a finite, separated
numerical dessin whose coordinate coincidences reproduce the prescribed
class-1 branch cycles?

## Runtime and provenance

The run used the deterministic domain-1 bundle built at project revision
`b9cf11876c22abd158d079b196d898e7bcbe8973`. Its pinned dependencies were:

- the Barth--Wenz official `mmc1` code archive, SHA-256
  `0e3202564229dfad668622f77c5d3c5011deac4b83d5ef10c700c3b9ced080c3`;
- SC Toolbox 3.1.3 at commit
  `6eb3a8abcda4b2185655b782053cf64e9d90665a`; and
- class-1 preprocessing input, SHA-256
  `1035a6f10819b34faac51db6155c9c682de017034db63d322ccd69c00f414e4c`.

The external runtime was MATLAB Online basic,
`26.1.0.3312084 (R2026a) Update 4`, on `GLNXA64`. The returned browser
archive has SHA-256
`b1cf2987fcf48c59f32fc18aab3b288ca6035d805e596e29e429ec925297832c`.
It includes third-party source and remains an ignored operational artifact
under `runs/`; the compact coordinates and hashes are committed.

## Independent intake

`scripts/intake_barth_wenz_matlab_result.py` checks the returned input and
driver against the bundle manifest, requires a successful transcript marker,
rejects a failure file or nonfinite coordinate, and matches all 23 sheet
coordinates in each fibre against cycles recomputed from the committed
permutation triple.

The intake obtained:

| metric | value |
| --- | ---: |
| SC-map accuracy | `6.6952288997922659e-09` |
| largest spread inside one prescribed cycle | `6.2941543479680769e-16` |
| closest distinct roots in one fibre | `0.0036951807258836927` |
| closest roots in different fibres | `0.0008017164061509711` |
| smallest separation / SC accuracy | `119744.43564966779` |

The resulting distinct-root partitions are exactly:

- zeros: `(8,8,4,2,1)`;
- ones: `(2^8,1^7)`; and
- poles: `(8,8,4,2,1)`.

The graphics-resource warning in the transcript arose from the toolbox
progress window in the headless online session. The SC solve continued,
reported its accuracy, completed welding, and wrote all requested outputs.

## Result

Pass as a **nondegenerate numerical dessin seed**. The smallest distinct-root
separation is more than `119,000` times the reported SC-map error, so the
predeclared domain-2 fallback is not justified at this stage.

This is not yet a numerical solution of the Belyi coefficient equations and
is not an exact Belyi map. The next gate is to choose a stable Möbius
normalization, translate the 25 distinct dessin coordinates into the
23-variable normalized root system, and measure the coefficient residual
before taking bounded Newton steps.

Test 0088 subsequently completed that refinement gate. Domain 1 did not yield
a nondegenerate candidate under either bounded method, so domain 2 is now
justified as the next independent conformal chart. This does not retract the
domain-1 drawing result recorded here. Test 0089 later completed domain 2 and
obtained a certified nondegenerate numerical root-system endpoint.

## Reproduction

Given the downloaded result archive and MATLAB environment record:

```sh
python3 -m zipfile -e \
  runs/8a-barth-wenz-matlab-class1-domain1-result-20260723.zip \
  /tmp/m23-matlab-domain1-result
python3 scripts/intake_barth_wenz_matlab_result.py \
  /tmp/m23-matlab-domain1-result/8a-barth-wenz-matlab-class1-domain1-b9cf118 \
  --environment \
    runs/8a-barth-wenz-matlab-class1-domain1-environment-20260723.txt \
  --result-archive \
    runs/8a-barth-wenz-matlab-class1-domain1-result-20260723.zip \
  --output /tmp/m23_8a_barth_wenz_class1_domain1_dessin.tsv
cmp /tmp/m23_8a_barth_wenz_class1_domain1_dessin.tsv \
  data/derived/m23_8a_barth_wenz_class1_domain1_dessin.tsv
python3 scripts/check_barth_wenz_matlab_result.py
```

Rebuilding the upload bundle and repeating `run_class1` is the full external
reproduction route.

## Evidence

- `data/derived/m23_8a_barth_wenz_class1_domain1_dessin.tsv`;
- `scripts/intake_barth_wenz_matlab_result.py`;
- `scripts/check_barth_wenz_matlab_result.py`; and
- output hashes embedded in the committed TSV.
