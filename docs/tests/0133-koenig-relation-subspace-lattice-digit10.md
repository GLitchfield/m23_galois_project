# Test 0133: König relation-subspace lattice audit at digit 10

## Question

Does the extra factor of 19 supplied by Test 0131 make a simultaneous shared
denominator visible in the canonical `568 x 3` chart at effective precision
`19^7`?

## Result

No, within the declared bounded audit.

The audit repeated Test 0130's deterministic subsets of 6, 8, 10, and 12
coordinates, four offsets, and five denominator weights on the 723 entries
unresolved by scalar reconstruction. The 80 LLL projections produced 502
distinct denominator proposals.

Every proposal was evaluated on all 1,704 chart entries and at effective
precisions `19^5`, `19^6`, and `19^7`. A credible proposal again had to occur
in at least two configurations and stabilize at least 90 percent (1,534) of
the full chart between the last two precisions.

No proposal passed. The best stabilized only 118 of 1,704 coordinates, had
support one, and produced maximum absolute numerator 446,786,202, essentially
the full centered range modulo 893,871,739. The best proposal occurring in
more than one configuration stabilized only 115 coordinates. No top-25
proposal placed more than one entry within the scalar symmetric bound of
21,140.

This is worse than Test 0130's best stability of 126 despite the extra factor
of 19 in precision, and remains near the random-scale expectation after
searching hundreds of proposals. It closes this bounded scalar/shared-scalar-
denominator strategy, not every possible simultaneous reconstruction.

## Validation

The Sage self-test still recovers a planted denominator of 12,347 with twelve
small numerators. The v1 mode reproduces the complete Test 0130 certificate
unchanged.

The Python checker independently rebuilds the three charts and verifies every
whole-chart numerator bound, squared norm, reconstruction-bound count, and
cross-precision stability count for the 25 top-ranked proposals. It confirms
that none reaches the predeclared credibility threshold. The Sage replay
independently reproduces the complete 502-candidate enumeration.

## Evidence

Implementation revision:
`b5b3524da9e1ea3f3b0abc6bd0155779a6b24774`.

```text
05ef09488d14685d40f1ff73d693ee5970a1aeeaa37f77c69b6beb51b8b6123e
  data/derived/m23_koenig_a_relation_subspace_lattice_pilot_digits10.tsv
```

Replay:

```sh
make check-koenig-relation-subspace-lattice-digits10
```

## Next gate

Do not purchase an eleventh digit with the current `uint64` implementation:
digit 10 is its checked safe limit, and neither scalar nor shared-scalar
reconstruction improved. Instead, reconstruct the three-dimensional
annihilator of the relation subspace in a basis-invariant way, allowing a
`GL_3(Q)` change of annihilator basis. A bounded rank-three lattice or
Plücker-coordinate pilot should be required to recover planted transformed
subspaces before it is run on the real chart.
