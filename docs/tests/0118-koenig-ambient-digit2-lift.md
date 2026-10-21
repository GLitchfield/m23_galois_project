# Test 0118: König ambient digit-2 lift

## Question

Does the recovered relation lift modulo `19^2` after allowing every
cutoff-105 coefficient, including coordinates that vanish modulo 19?

## Method

The normalized ambient ansatz contains 9,506 numerator and 5,671 denominator
coordinates. Fixing `P[0,1]=1` leaves 15,176 correction variables. The exact
mixed family was recomputed in `(Z/19^2 Z)[s]/(s^16384)`, with 16,000
coefficients used for fitting and 384 reserved as holdouts.

FFPACK computed deterministic row and column rank profiles of the full fitting
matrix. Its rank is 15,091, leaving an 85-dimensional normalized gauge kernel:
the 36 plane multiples from Test 0116 plus 49 other relation directions. The
pilot fixed the gauge by setting nonpivot correction coordinates to zero,
solved the resulting 15,091-square system, and checked every series row.

## Result

The ambient digit-2 lift succeeds:

```text
fitting nonzero residuals: 0 of 16,000
holdout nonzero residuals: 0 of 384
```

The correction activates 645 coordinates that were zero modulo 19 and changes
9,942 coordinates on the original nonzero support. This explains Test 0117:
the sparse support was rigid but omitted coefficients required by the
characteristic-zero lift. The complete nonzero coefficient set modulo 361 is
committed for the next digit.

This is local formal evidence for the coefficient map, not yet a recovered
characteristic-zero rational function or a global identity.

## Evidence

Implementation revision:
`5c0d98c650da37e018fb231a2076a2a831eb6440`.

```text
51ed3d5595037b989e090ded514da596971b8e8217b8eaaf2c79d49bdaeff83a
  data/derived/m23_koenig_a_relation_ambient_digit2.tsv
9d9240a1330daf191f733d7a76c54fd8d5f11926aa3d38338e1f5cd97ca8549a
  data/derived/m23_koenig_a_relation_coefficients_mod361.tsv
```

The run used Sage 10.9, took 17 minutes 16 seconds wall time, and reached
4,006,604 KiB maximum RSS. A full replay is:

```sh
make check-koenig-relation-ambient-digit2
```
