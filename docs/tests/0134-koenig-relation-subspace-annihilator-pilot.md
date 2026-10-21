# Test 0134: König relation-subspace annihilator pilot

## Question

Can a basis-invariant lattice search recover a short rank-three annihilator of
the canonical 568-dimensional relation subspace, even though scalar and
shared-scalar-denominator reconstruction fail?

## Result

No, within the declared bounded pilot.

The annihilator has canonical modular form

```text
[ I_3 ]
[ -C  ]
```

for the `568 x 3` chart `C`. Rather than fixing the three canonical columns,
the pilot searches for arbitrary leading vectors in `(Z/19^7 Z)^3`; three
independent successes would permit an unrestricted `GL_3(Q)` change of
annihilator basis.

Deterministic subsets of 6, 8, 10, and 12 chart rows, four offsets, and five
leading-coordinate weights produced 80 low-dimensional q-ary LLL projections
and 856 distinct candidate directions. Each candidate was extended to all
571 annihilator coordinates and compared at effective precisions `19^5`,
`19^6`, and `19^7`.

A credible direction had to occur in at least two configurations and stabilize
at least 90 percent (514) of its 571 coordinates between the last two
precisions. No candidate passed. The best stabilized only 61 coordinates, had
support one, and reached maximum absolute coefficient 446,538,951, essentially
the full centered range modulo 893,871,739. The best repeated proposal
stabilized only 55 coordinates. No credible direction exists in the bounded
candidate set, so its leading rank is zero rather than three.

This rules out a simple small-height annihilator hidden only by the canonical
`GL_3` basis choice. It does not rule out a high-height rational subspace or
structure hidden by the ambient 571-dimensional modular kernel basis.

## Validation

The planted gate constructs a nontrivial integral `3 x 3` basis transform and
568 small tail rows, converts that small annihilator to a random-looking
canonical modular chart, and runs the same subset lattices at modulus `19^7`.
The pilot recovers all three planted transformed directions among five short
vectors. During implementation this gate caught two independent unsigned
modular-negation errors before real data was accepted.

The Python checker independently rebuilds all three charts and verifies every
full-vector maximum, squared norm, symmetric-bound count, cross-precision
stability count, support count, ordering key, and credibility condition for
the top 25 candidates. Sage independently replays the complete 856-candidate
enumeration.

## Evidence

Implementation revision:
`44a7a4b7669fc8b9c26f166a6ab4f661ca6c85ed`.

```text
3e0acd8bd359588a9350b186e37fb4768604f3fe03851367dbb5d98dcd08e43d
  data/derived/m23_koenig_a_relation_subspace_annihilator_pilot.tsv
```

Replay:

```sh
make check-koenig-relation-subspace-annihilator
```

## Next gate

Return to the original 15,722 monomial coefficient coordinates. The
571-dimensional ambient kernel basis is chosen by modular pivot elimination
and need not expose small rational structure, even after an internal
`GL_3` change. Quotient the known 91-dimensional plane-multiple control sector
and stratify the remaining relation space by numerator/denominator degree or
support. Require a smaller canonical graded block before attempting any
further rational reconstruction or purchasing more 19-adic precision.
