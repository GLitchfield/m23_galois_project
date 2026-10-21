# Explicit M23 over Q

> **Status:** inactive since 2026-08-01. This map records decisions made while
> the project was active. It has no open frontier, and no decision tickets are
> included in this release.

## Destination

Produce an explicit polynomial over `Q` whose Galois group is independently
certified to be `M23`, together with a reproducible construction and evidence
trail strong enough for mathematical scrutiny.

## Notes

- Domain: inverse Galois theory, Hurwitz spaces, explicit covers, arithmetic
  geometry, and certified computation.
- Execution is part of this map. Bounded computations must resolve a stated
  uncertainty and carry advancement, redirection, and closure criteria.
- The committed local tracker is canonical until an explicit migration
  decision selects another issue tracker.
- Existing numbered tests and artifacts are evidence, not decision tickets.
- Prefer the smallest decisive arithmetic gate before a long construction or
  exhaustive search.
- Companion upstream skills such as grilling, domain modeling, prototype, and
  research are optional capabilities, not hidden dependencies. Use only skills
  actually installed and permitted in the current session.

## Decisions so far

- [Require reproducible, independently checked computation](../reproducibility.md) — committed results carry provenance, independent checks, and deliberate exact-replay paths.
- [Close the König M24 component by a complete local obstruction](../tests/0151-m24-koenig-genus11-tropical-exhaustion.md) — the authenticated genus-11 normalization has no `Q_2`-point.
- [Stop the current generic second-prime and bounded reconstruction routes](../tests/0145-koenig-f19-solver-positive-control.md) — the positive control and lattice gates fail before supplying a characteristic-zero König family.
- [Separate routine certificate validation from exact replay](../reproducibility.md) — `make test` is the required commit gate; `make test-replay` and `make test-long` retain exhaustive regeneration.
- [Adopt the M23 Wayfinder operating contract](README.md) — strategic work now advances through a committed decision frontier while retaining execution and numbered computational evidence.
- [Require bounded Codex/Fable review for Wayfinder decisions](README.md#codexfable-review-boundary) — route selection, redirection, closure, and frontier promotion receive an advisory adversarial review without weakening independent proof or computation requirements.

## Out of scope

- Reopening the obstructed König genus-11 component without a defect in its
  certificate, a genuinely different component, or new primary-source data.
- Treating a component defined over `Q` or a rational boundary point as an
  `M23/Q` realization by itself.
- Unbounded numerical, braid, finite-field, or lattice searches without a
  deterministic stopping rule and a decision they can resolve.
- Importing competition state, credentials, or operational assumptions from
  the neighboring `inverse_galois` project.
