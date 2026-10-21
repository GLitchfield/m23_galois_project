# Test 0084: open Barth--Wenz preprocessing for the 8A target

## Question

Can the Magma-only first stage of the published Barth--Wenz conformal-welding
workflow be replaced locally and applied reproducibly to a certified
`(8A,8A,2A)` target?

## Method

The official article ancillary archives were fetched from the journal and
recorded by SHA-256, but were not copied into the repository. The open Python
implementation follows `Step1_ComputeFundamentalDomains.txt`: it constructs
petalled fundamental domains, evaluates their hyperbolic-kite centers, detects
the borders, pairs reverse-oriented edges, and writes the MATLAB variables
expected by the next stage.

The authors randomize part of their breadth-first traversal. The port sorts
that traversal to make its output reproducible. It conservatively omits the
optional Magma normalizer search and therefore emits `ConjugateEdges = []`.

Two input families form the regression:

1. the published degree-52 `52.txt` fixture from the authors' second
   ancillary archive; and
2. all 28 certified M23 targets from
   `data/derived/m23_8a_8a_2a_inner_classes.tsv`, with class 1 frozen as the
   baseline MATLAB handoff.

For the M23 product-one triple `(a,b,c)` with `c` an involution, the workflow
uses `(x,y)=(a,c)`. Then `(xy)^-1=c a^-1=c b c`, which is conjugate to the
original second 8A branch cycle.

## Result

Both preprocessing cases pass all declared invariants:

| input | degree | orders `(x,y,z)` | genus | domains | border edges per domain | deterministic digest |
| --- | ---: | --- | ---: | ---: | --- | --- |
| published `52.txt` | 52 | `(8,2,4)` | 0 | 4 | `70,70,70,70` | `ee01407b8d8df203a2562465e447a8238408b77231b66cd96505095d639f68d0` |
| M23 class 1 | 23 | `(8,2,8)` | 0 | 2 | `34,34` | `ff1b5044fb061edf47032ed7db3372d4d850bf6ee1bd1018d58b1f9532222911` |

All 28 M23 targets pass the same structural gate and produce two fundamental
domains. For every domain, the word list maps bijectively to all sheets. Every
gluing identifier occurs exactly twice, and the second edge reverses the
sheets and orientation of the first. The class-1 MATLAB handoff is regenerated
byte-for-byte in the test.

This closes the Magma gap only for the preprocessing layer. No claim is made
that the deterministic domains are byte-identical to one random upstream run,
that the unported normalizer optimization would be empty, or that a numerical
Belyi map has been computed. The next gate is to run the handoff through the
MATLAB Schwarz--Christoffel stage (or a validated compatible replacement).

## Reproduction

```sh
make check-8a-barth-wenz
python3 scripts/barth_wenz_preprocess.py \
  --published-52 --output /tmp/barth-wenz-52-matlab-input.m
python3 scripts/barth_wenz_preprocess.py \
  --target-class 1 \
  --output data/derived/m23_8a_barth_wenz_class1_matlab_input.m
```

## Evidence

- `scripts/barth_wenz_preprocess.py`;
- `scripts/test_barth_wenz_preprocess.py`;
- `data/derived/m23_8a_barth_wenz_class1_matlab_input.m`; and
- `barth_wenz/README.md`.
