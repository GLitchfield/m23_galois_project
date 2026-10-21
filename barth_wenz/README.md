# Barth--Wenz preprocessing route

This directory documents the open first stage of the conformal-welding method
in Dominik Barth and Andreas Wenz, *Computation of Belyi maps with prescribed
ramification and applications in Galois theory*, Journal of Algebra 569
(2021), 616--642
([DOI](https://doi.org/10.1016/j.jalgebra.2020.10.040)).

The authors' ancillary workflow has two distinct runtime layers:

1. `Step1_ComputeFundamentalDomains.txt` uses Magma to turn a transitive
   permutation triple, with the second generator an involution, into
   fundamental-domain words and boundary-gluing data.
2. The later scripts use MATLAB and the Schwarz--Christoffel Toolbox for the
   numerical dessin, welding, and coefficient-recovery stages.

`scripts/barth_wenz_preprocess.py` openly reimplements the first layer. It does
not repackage the authors' source. The implementation is deterministic where
their breadth-first traversal is randomized, omits their optional
normalizer-based symmetrization, and emits `ConjugateEdges = []`. Those changes
may select a different valid fundamental domain or forgo a symmetry
acceleration; they do not change the permutation triple.

The official ancillary archives used for validation are:

| archive | content used | SHA-256 |
| --- | --- | --- |
| [`mmc1`](https://ars.els-cdn.com/content/image/1-s2.0-S0021869320305810-mmc1.zip) | preprocessing algorithm | `0e3202564229dfad668622f77c5d3c5011deac4b83d5ef10c700c3b9ced080c3` |
| [`mmc2`](https://ars.els-cdn.com/content/image/1-s2.0-S0021869320305810-mmc2.zip) | published degree-52 fixture `52.txt` | `32f7d08e6cc111685e332d997321fb7c807e403198b302c9c94dad4e193c4876` |

The regression reproduces the degree-52 fixture's exact passport and checks
transitivity, genus zero, word-to-sheet bijectivity, and paired border
orientations. It then applies the same structural gate to all 28 certified M23
targets and freezes the class-1 output as the baseline handoff. If the
original target is the product-one triple `(a,b,c)` of types
`(8A,8A,2A)`, the preprocessing input is `(x,y)=(a,c)` because `y` must be
an involution. Its third branch cycle is
`z=(ac)^-1=c a^-1=c b c`, so it is conjugate to the original second `8A`
element and has the required passport.

Run:

```sh
make check-8a-barth-wenz
python3 scripts/barth_wenz_preprocess.py \
  --target-class 1 \
  --output data/derived/m23_8a_barth_wenz_class1_matlab_input.m
```

The committed class-1 output is ready for the authors'
`Step2_DrawDessin.m`. It is not a Belyi map or a numerical solution. The
project now builds an upload bundle for the free MATLAB Online runtime without
copying the journal ancillary code or SC Toolbox into the repository:

```sh
python3 scripts/prepare_barth_wenz_matlab.py \
  --output-dir runs/8a-barth-wenz-matlab-class1-domain1 \
  --domain-index 1
```

The builder downloads and hash-checks the official Barth--Wenz code archive
and BSD-licensed SC Toolbox 3.1.3, pins the selected domain, adds a
noninteractive result recorder, and writes a deterministic zip. Domain 2 can
be prepared independently if the first polygon suffers from numerical
crowding. See `barth_wenz/matlab/README_MATLAB_ONLINE.txt`.

GNU Octave and SchwarzChristoffel.jl were evaluated before choosing that
handoff. Octave does not support MATLAB package imports or the class metadata
used by SC Toolbox 3.1.3; removing those first syntax barriers still reaches
incompatible method/property dispatch. The Julia package solves an exterior
polygon map, not the interior disk map required here, and fails on the actual
dessin arcs. Neither is presented as a working substitute.

The authenticated domain-1 MATLAB Online run completed on 2026-07-23 with
SC-map accuracy `6.6952288997922659e-09`. Independent intake reproduced the
prescribed cycle partitions and found the closest distinct roots more than
`119,000` times farther apart than that reported error. The compact seed and
its output hashes are committed as
`data/derived/m23_8a_barth_wenz_class1_domain1_dessin.tsv`.

All six Möbius normalizations were subsequently translated into the
chart-aware root equations. Normalization `(1,4,2)` alone passed the
predeclared seed gates. Bounded direct Newton reduced the relative residual to
`7.37e-12` only by approaching an `F`--`Q` collision; a seven-factor saturated
continuation exposed the boundary as an infinity escape. Domain 1 therefore
passes the numerical-dessin seed gate but not the Belyi-map gate.

The authenticated domain-2 run then completed with SC-map accuracy
`1.8412309769781973e-8`. Its `(1,4,2)` strong seven-factor path reached the
target in 28 accepted steps, with coefficient residual `7.49e-14`, minimum
all-fibre separation `0.001554`, and successful interval certification.
Independent Python evaluation gives relative residual `3.17e-16`, condition
`6.12e8`, and verifies every scaled saturation equation. This passes the
numerical root-system gate.

Exact-presentation Newton refinement now gives 4096-bit coefficients with
maximum residual `5.09e-1231`. Numerical cover-loop lifting is stable under a
512-to-1,024-step mesh doubling. GAP identifies the recovered transitive group
as `M23`, and simultaneous conjugacy against all 28 committed classes uniquely
returns class 1. Independent 8,192-bit and 16,384-bit refinements now support
bounded recognition of all 23 coefficients in one irreducible degree-28 field.
Exact substitution and an independent GAP/Sage verifier prove the target
ramification. Test 0092 later replaced the numerical cover-loop lifting with an
interval-arithmetic monodromy proof. This does not realize `M23` over `Q`. See
tests 0086 and 0088--0092.
