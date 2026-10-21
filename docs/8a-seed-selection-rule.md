# Predeclared 8A chart-selection rule

This rule is fixed before inspecting the 504 chart-level conditioning rows or
the 18 class-22 circle-packing rows. Its purpose is to decide whether one
class-22 continuation experiment is justified without retrospectively choosing
whichever chart has one favorable diagnostic.

## Inputs

For each class, cyclic rotation, and normalization chart, the Tutte ledger
records relative residual, row/column-equilibrated Jacobian condition estimate,
and normalized root separation. The class-22 transfer ledger records the same
three diagnostics at the actual two-refinement circle-packing seeds.

The two ledgers must contain exactly the same 18 class-22 chart keys.

## Joint ordinal rule

Within each ledger, rank the 18 charts separately by:

1. increasing relative residual;
2. increasing equilibrated Jacobian condition; and
3. decreasing normalized root separation.

Ties are resolved by rotation and then the literal normalization string. Each
chart therefore receives six ordinal ranks. Select lexicographically by:

1. smallest worst rank;
2. smallest sum of all six ranks;
3. smallest sum of the two residual ranks;
4. smallest sum of the two condition ranks; and
5. rotation and normalization.

The selected chart must also be jointly Pareto-undominated across all six raw
diagnostics.

## Absolute transfer gates

The actual circle-packing seed must additionally have:

- relative residual at most `0.5`;
- equilibrated Jacobian condition at most `1e14`; and
- normalized root separation at least `1e-8`.

These gates are deliberately coarse. The condition ceiling retains at least
roughly two decimal digits under a double-precision perturbation estimate; the
separation floor is near the square-root scale of double-precision epsilon;
and the residual ceiling prevents a seed whose equation error is comparable to
the full coefficient scale. Passing them does not imply convergence or a Belyi
map. Future high-precision work must keep its own stricter endpoint gates.

## Decision

All structural, Pareto, finiteness, residual, condition, and separation gates
must pass to authorize the next bounded class-22 continuation. Failure supports
only this statement:

> Under the predeclared joint rule and transfer thresholds, the tested Tutte
> and two-refinement circle-packing seed family supplies no admissible
> class-22 chart.

It does not constrain map existence, other seed constructions, or Magma
convergence. The rule is implemented by `scripts/select_8a_belyi_seed.py` and
covered by order-independence and fail-closed synthetic regressions.
