# Test 0085: Schwarz--Christoffel runtime gate for the 8A target

## Question

Can a free local MATLAB-compatible or native open-source runtime execute the
remaining Barth--Wenz interior Schwarz--Christoffel stage, and if not, can the
faithful computation be reduced to a bounded, provenance-complete external
run?

## Dependency audit

The authors' `Step2_DrawDessin.m` calls `polygon`, `diskmap`, `accuracy`, and
`evalinv` from Toby Driscoll's
[Schwarz--Christoffel Toolbox](https://github.com/tobydriscoll/sc-toolbox),
then applies the supplied welding routine. The toolbox is BSD-3-Clause and
declares no dependency beyond core MATLAB. The Barth--Wenz ancillary
instructions do not pin a toolbox revision, so this project pins stable
release 3.1.3 at commit
`6eb3a8abcda4b2185655b782053cf64e9d90665a`.

The open-runtime comparison produced three distinct answers:

| route | relevant capability | gate |
| --- | --- | --- |
| GNU Octave 10.3.0 | MATLAB-like numerical runtime | Rejected locally: the unmodified toolbox stops because Octave does not implement its `import sctool.*` statements. Removing that first barrier exposes further incompatible class metadata and method/property dispatch, so a no-op shim is not a faithful run. |
| [SchwarzChristoffel.jl 0.1.17](https://jdeldre.github.io/SchwarzChristoffel.jl/latest/) | Open Julia parameter and inverse solvers | Rejected for this task: its documented `ExteriorMap` maps to the polygon exterior, whereas Barth--Wenz requires the polygon interior mapped to the disk. |
| [MATLAB Online basic](https://www.mathworks.com/products/matlab-online/matlab-online-versions.html) | Core MATLAB plus user-uploaded BSD toolbox | Faithful available route. It is free with a MathWorks account, currently limited to 20 hours per month and 15 minutes of continuous computation per basic session. |

These are capability distinctions, not claims that no future Octave port or
other conformal mapper could work.

## Handoff

`scripts/prepare_barth_wenz_matlab.py` downloads and verifies:

- the official Elsevier `mmc1` archive, SHA-256
  `0e3202564229dfad668622f77c5d3c5011deac4b83d5ef10c700c3b9ced080c3`;
- SC Toolbox 3.1.3, archive SHA-256
  `dae0bf5b3c5d6dfb70b7076e79f27c9197c27224ec491b9dcad271ad2dbc2b1a`;
  and
- the committed class-1 MATLAB input, SHA-256
  `1035a6f10819b34faac51db6155c9c682de017034db63d322ccd69c00f414e4c`.

It pins either of the two class-1 fundamental domains, adds a driver that
records finite output, SC-map accuracy, coordinates, a MATLAB `.mat` file,
and the complete transcript, then produces a deterministic zip. Independent
rebuilds at revision `b9cf11876c22abd158d079b196d898e7bcbe8973`
gave:

| domain | bundle SHA-256 |
| ---: | --- |
| 1 | `801ad0305f5485461dfd10c23482e29a1b718f129e9b0833f5e5db86c1ea69cc` |
| 2 | `ba026d46bba04c7b2d095523d983d675cba88ac5b190816b5cf91c03f8921f2a` |

The zips remain operational artifacts under `runs/`; only their compact
manifest is committed. Domain 2 is already prepared because the authors
specifically recommend changing fundamental domains when crowding or inverse
mapping is poor.

## Result

The software and provenance handoff passes. On 2026-07-23, domain 1 completed
under MATLAB Online basic, MATLAB
`26.1.0.3312084 (R2026a) Update 4`, with SC-map accuracy
`6.6952288997922659e-09` and finite output. Test 0086 independently intakes
and checks that result. At this runtime-gate stage, domain 2 remained an unused
fallback. Test 0088 later found that both bounded domain-1 refinements reach a
collision boundary. Test 0089 then completed domain 2 and obtained a certified
nondegenerate numerical root-system endpoint.

Neither a MATLAB `completed` marker nor the accepted numerical dessin is by
itself a Belyi map. The coordinates must still seed Newton refinement, exact
recognition, exact ramification, and independent monodromy verification.

## Reproduction

```sh
python3 scripts/prepare_barth_wenz_matlab.py \
  --output-dir runs/8a-barth-wenz-matlab-class1-domain1-b9cf118 \
  --domain-index 1
python3 scripts/prepare_barth_wenz_matlab.py \
  --output-dir runs/8a-barth-wenz-matlab-class1-domain2-b9cf118 \
  --domain-index 2
python3 scripts/check_barth_wenz_matlab_bundles.py --bundle-root runs
```

The reproducible negative Octave gate is:

```sh
./scripts/setup-barth-wenz-octave.sh
./scripts/check-barth-wenz-octave-incompatibility.sh \
  runs/8a-barth-wenz-matlab-class1-domain1-b9cf118
```

## Evidence

- `data/derived/m23_8a_barth_wenz_matlab_bundles.tsv`;
- `scripts/prepare_barth_wenz_matlab.py`;
- `scripts/check_barth_wenz_matlab_bundles.py`;
- `scripts/check-barth-wenz-octave-incompatibility.sh`;
- `barth_wenz/matlab/run_class1.m`;
- `barth_wenz/matlab/README_MATLAB_ONLINE.txt`; and
- `docs/tests/0086-8a-barth-wenz-matlab-result.md`.
