# Test 0078: predeclared class-22 seed-transfer gate

## Correction

Test 0087 found that the alternate Möbius charts were evaluated with the wrong
exponent placement in the Python residual and Jacobian. After correction and
regeneration, the same predeclared rule still selects rotation 1 and
normalization `(2,1,4)`, but its circle residual is `0.715466`, above the
frozen `0.5` gate. The committed verdict is now `admissible=false`, with
`circle_residual_gate` recorded as the failure. This test no longer authorizes
a continuation; the result below is retained as a superseded historical
record.

## Question

Does the class-level advantage found in test 0077 survive the actual
two-refinement circle-packing construction strongly enough to justify one
bounded saturated continuation?

## Method

Before inspecting the chart-level results, revision `9487d28` fixed the joint
ordinal selection rule and absolute transfer thresholds in
`docs/8a-seed-selection-rule.md`. Revision `9adfe97` then fixed the generators,
provenance schema, and independent reconstruction checker before the target
artifacts were produced.

The Tutte calculation exports all 504 rows (28 classes, three rotations, six
charts). An independent checker reconstructs every statistic and selected
chart in the earlier 28-row aggregate. For class 22, the actual 4,970-vertex,
14,904-edge, 9,936-triangle circle pack is computed once in each rotation and
all six normalization charts are evaluated on each geometry.

The predeclared rule ranks residual, equilibrated Jacobian condition, and
normalized root separation separately in both ledgers. It minimizes the worst
of those six ranks, with fixed tie-breakers, and requires joint Pareto
undominance plus the three absolute circle-packing gates.

## Historical result (superseded by test 0087)

Passed. The rule selects rotation 1 and normalization `(2,1,4)`. Its metrics
are:

| diagnostic | Tutte | two-refinement circle packing |
| --- | ---: | ---: |
| relative residual | `0.364416` | `0.105582` |
| equilibrated Jacobian condition | `7.70e12` | `1.02e12` |
| normalized root separation | `0.001635` | `0.004003` |

The six ordinal ranks have maximum 7 and sum 23. The chart is jointly
Pareto-undominated. Its circle residual is below `0.5`, condition is below
`1e14`, and separation is above `1e-8`, so the recorded decision is
`admissible=true` with no failed gate.

This was a seed-selection result, not a Belyi map or evidence of convergence.
Its authorization is withdrawn. Exact ramification and monodromy checks remain
mandatory for any candidate endpoint.

## Reproduction

The cheap ledger and all structural checks are local:

```sh
make reproduce-8a-conditioning-census
make check-8a-conditioning-census
make check-8a-seed-transfer
```

The circle transfer requires the versions pinned in
`requirements-8a-belyi-pilot.txt`:

```sh
python scripts/census_8a_belyi_circle_transfer.py \
  --class-id 22 --refinements 2 \
  --output data/derived/m23_8a_belyi_circle_transfer.tsv
python3 scripts/select_8a_belyi_seed.py \
  data/derived/m23_8a_belyi_conditioning_seeds.tsv \
  data/derived/m23_8a_belyi_circle_transfer.tsv \
  --output data/derived/m23_8a_belyi_seed_selection.tsv
```

## Evidence

- `docs/8a-seed-selection-rule.md`;
- `data/derived/m23_8a_belyi_conditioning_seeds.tsv`;
- `data/derived/m23_8a_belyi_circle_transfer.tsv`;
- `data/derived/m23_8a_belyi_seed_selection.tsv`;
- `scripts/census_8a_belyi_circle_transfer.py`;
- `scripts/select_8a_belyi_seed.py`; and
- `scripts/check_8a_belyi_seed_transfer.py`.
