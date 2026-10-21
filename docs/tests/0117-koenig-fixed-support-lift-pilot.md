# Test 0117: König fixed-support lift pilot

## Question

Does the unique normalized mod-19 relation on the candidate's nonzero
support lift through `19^4` when every fitting and holdout series equation is
checked?

## Method

The pilot recomputed the exact mixed family in
`(Z/19^4 Z)[s]/(s^16384)`, packed all 10,573 unknown coefficients after the
normalization `P[0,1]=1`, and reserved the last 384 series coefficients as
untouched holdouts. FFPACK computed a deterministic row-rank profile from all
16,000 fitting rows. Its 10,573 independent rows supplied one reusable
finite-field inverse for digitwise Hensel correction.

## Result

The fitting matrix has exact normalized rank `10,573`, confirming the rank
inferred in Test 0116. The unique correction on the independent square does
not satisfy the other equations modulo `19^2`:

```text
fitting nonzero residuals: 5,121
holdout nonzero residuals:   359 of 384
```

Thus the fixed nonzero mod-19 support is rigid but does not lift. This does
not reject the characteristic-zero coefficient map: coefficients that are
zero modulo 19 may acquire nonzero multiples of 19. The next solver must use
the full cutoff-105 ambient column set and quotient its 36-dimensional plane-
multiple freedom, rather than freezing the sparse mod-19 support.

## Evidence

Implementation revision:
`74f8870cb780ab1ef87790d1c796ad616b049060`.

```text
3c23173f9195b777e7b275b7fc340100b87adb7574dae177ced490d0937b332e
  data/derived/m23_koenig_a_relation_lift_pilot.tsv
```

The run used Sage 10.9, took 15 minutes 8 seconds wall time, and reached
3,422,704 KiB maximum RSS. A full replay is:

```sh
make check-koenig-relation-lift-pilot
```
