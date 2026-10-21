# Test 0130: König relation-subspace lattice pilot

## Question

Can simultaneous low-dimensional lattice reduction recover a shared
denominator for the canonical `568 x 3` relation-subspace chart at effective
precision `19^6`, where entrywise reconstruction has plateaued?

## Result

Not within the declared bounded pilot.

The audit selected deterministic subsets of 6, 8, 10, and 12 coordinates from
the 718 entries unresolved by scalar reconstruction. Four offsets and five
denominator weights produced 80 LLL projections and 472 distinct denominator
proposals.

Every proposal was then evaluated on all 1,704 chart entries and at effective
precisions `19^4`, `19^5`, and `19^6`. A credible proposal had to occur in at
least two projection configurations and stabilize at least 90 percent
(1,534) of the full chart between the last two precisions.

No proposal passed. The best stabilized only 126 of 1,704 coordinates, had
support one, and produced maximum absolute numerator 23,522,308—essentially
the full centered range modulo 47,045,881. For comparison, a random-scale
denominator is expected to stabilize about `1704/19 = 89.7` coordinates.
The best repeated proposal stabilized only 114 coordinates.

This is a bounded negative result, not a proof that no shared denominator or
rational subspace exists.

## Validation

The Sage self-test plants denominator 12,347 with twelve small numerators at
the same modulus. The identical LLL routine recovers the planted denominator,
so the real negative result is not caused by a vacuous lattice construction.

The Python checker independently rebuilds the charts and verifies every
whole-chart numerator bound, squared norm, reconstruction-bound count, and
cross-precision stability count for the 25 top-ranked proposals. It confirms
that none reaches the predeclared credibility threshold. The Sage replay
independently reproduces the complete 472-candidate enumeration.

## Evidence

Implementation revision:
`c83f656d51b9a93e7cb3f733e7ac6314937b4e46`.

```text
56ddf77916d6f7d0a2eeb0728c0ad1d8d0b0ffca1bc51aae7facb2f228ef91b8
  data/derived/m23_koenig_a_relation_subspace_lattice_pilot.tsv
```

Replay:

```sh
make check-koenig-relation-subspace-lattice
```

## Next gate

One more 19-adic digit is now justified: continue the full subspace through
`19^10 = 6,131,066,257,801`, still within `uint64`. This supplies effective
precision `19^7 = 893,871,739` and raises the scalar symmetric bound to
21,140. Repeat both scalar and simultaneous audits; a true shared-denominator
signal should improve sharply under the extra factor of 19 rather than remain
near random scale.
