# Test 0087: 8A normalization audit and heuristic correction

## Question

Did the Python seed diagnostics evaluate each of the six advertised Möbius
normalization charts against the matching exponent placement in the Belyi
equations?

## Finding

No. `initial_from_positions` mapped the distinguished points according to its
`normalization` argument, but the Python `residual_jac` helper always used
exponents `(4,2)` at `(0,1)`, implicitly fixing the point at infinity to
multiplicity 1. The alternate chart labels, coordinates, and equation
residuals therefore described different systems. The scale fit inherited the
same mismatch.

The Julia root system already used its normalization argument correctly, and
its all-chart agreement test was sound. Exact permutation, braid, passport,
and boundary-link results do not call this Python numerical helper and are
unaffected.

## Correction

Revision `cfc99efa1ef322846935385319b8e26b07bc77ed` made the Python residual,
Jacobian, scale fit, direct Newton method, and continuation helpers explicitly
chart-aware. A regression now checks the alpha-column polynomial for both
`(4,2,1)` and `(2,1,4)`.

The 28-class Tutte census, 504-row chart ledger, class-22 circle-transfer
ledger, and selection decision were regenerated together from the corrected
code. The earlier claims in tests 0077 and 0078 are superseded:

- the smallest cheap Tutte residual is now class 6, normalization `(1,4,2)`,
  at `0.0163974`, but that chart has condition estimate `4.19e18` and is not
  promoted as a robust solver seed;
- the predeclared class-22 rule still chooses rotation 1 and `(2,1,4)`, but
  its corrected circle residual is `0.715466`, above the frozen `0.5` gate;
  and
- the corrected decision is `admissible=false`, failing
  `circle_residual_gate`.

Consequently, test 0078 no longer authorizes the class-22 continuation.
Test 0080 remains an accurate record of a computation that was actually run,
but its authorization premise was based on the faulty diagnostic and it
cannot be used as evidence about the correctly evaluated selected seed.

## Result

The normalization audit fails the old heuristic artifacts and passes the
corrected implementation and regenerated evidence. No exact result is
retracted. The project must not use the former “class 22 is best” conclusion
for future numerical prioritization.

## Reproduction

```sh
make reproduce-8a-conditioning-census
PYTHONPATH=/tmp/m23_8a_python_deps \
  python3 scripts/census_8a_belyi_circle_transfer.py \
    --class-id 22 --refinements 2 \
    --output data/derived/m23_8a_belyi_circle_transfer.tsv
python3 scripts/select_8a_belyi_seed.py \
  data/derived/m23_8a_belyi_conditioning_seeds.tsv \
  data/derived/m23_8a_belyi_circle_transfer.tsv \
  --class-id 22 \
  --output data/derived/m23_8a_belyi_seed_selection.tsv
make check-8a-conditioning-census
make check-8a-seed-transfer
```

## Evidence

- `scripts/pilot_8a_belyi_numeric.py`;
- `scripts/test_census_8a_belyi_conditioning.py`;
- `data/derived/m23_8a_belyi_conditioning_census.tsv`;
- `data/derived/m23_8a_belyi_conditioning_seeds.tsv`;
- `data/derived/m23_8a_belyi_circle_transfer.tsv`; and
- `data/derived/m23_8a_belyi_seed_selection.tsv`.
