# Test 0121: König homogeneous degree-110 kernel

## Question

Does any genuine degree-110 relation survive modulo `19^4` when the complete
homogeneous relation space is refined, without fixing a normalization or
choosing one mod-`19^3` seed?

## Result

Yes. The normalized rank profile from Test 0120 determines a unit
`15,151 x 15,151` pivot block. Eliminating it modulo `19^4` reduces the full
homogeneous system to 571 free coordinates and

```text
849 nonpivot fitting rows
384 untouched holdout rows
```

The reduced system is identically zero through its first two base-19 digits.
At digit 4, it has rank exactly three. Consequently the liftable mod-19
directions have the profile

```text
precision   surviving directions   numerator-projection rank
19                         571                         480
19^2                       571                         480
19^3                       571                         480
19^4                       568                         477
```

The training-only and training-plus-holdout calculations give the identical
568-dimensional subspace. Thus 568 of the 571 mod-19 directions survive
through `19^4`; 477 have nonzero numerator projection and are genuine
`P-aQ` relations rather than the 91 numerator-zero plane multiples.

A concrete witness, canonically selected from the full block kernel and
normalized by `P[0,1]=1`, has 11,667 nonzero coefficients modulo 130,321.
Direct exact evaluation gives zero residual on all 16,000 fitting terms and
all 384 holdouts.

## Relationship to Test 0120

Test 0120 remains a correct fixed-direction obstruction. Its selected mod-19
direction is not in the 568-dimensional surviving subspace. Multiplying that
direction by the independently reduced digit-4 obstruction reproduces
exactly its 799 fitting and 368 holdout failures.

The issue was therefore not merely the choice of digit-2 or digit-3 gauge:
the digit-4 reduced block has zero tail rank, so those lower-digit corrections
cannot change the obstruction. Instead, the original selected mod-19 relation
was one of three obstructed directions, while 568 alternative directions
survive.

## Method and certificate

The calculation does not form a 16,000-by-15,722 Howell form directly.
Instead it:

1. lifts the unit pivot-block elimination through `19^4`;
2. forms the exact Schur complement on nonpivot and holdout rows;
3. divides its forced factor of 19;
4. encodes each congruence level as a block-lower-triangular matrix over
   `F_19`; and
5. computes the projected kernel and its numerator image.

The committed reduced certificate contains the Schur rows, the numerator map,
the pivot/free partition, and the final projected bases. The independent Sage
checker rebuilds every block rank and projected rank, validates the concrete
witness in reduced coordinates, and recovers Test 0120's residual counts from
the old direction.

## Evidence

Implementation revision:
`b38c8ff4d7e9ecffb26d040ebf492b4b76a55f00`.

```text
d88ba9707d8d105128416165d6e9601f6f40ee3e24862240e82a8ac39443464c
  data/derived/m23_koenig_a_relation_homogeneous_degree110.tsv
28876c75d75d4ab24501911053aee7ff816d954d800aa9f43cd25874ab6c8e8b
  data/derived/m23_koenig_a_relation_homogeneous_degree110_reduced.npz
c4e2648bdb2773fe05b711f65e9792711be178958874a333bc0915d19abedb85
  data/derived/m23_koenig_a_relation_homogeneous_degree110_coefficients_mod130321.tsv
```

The production run used Sage 10.9, took 11 minutes 8.80 seconds wall time,
and reached 6,640,392 KiB maximum RSS.

## Next gate

Continue the complete 568-dimensional surviving subspace, not just the one
witness, to higher 19-adic precision. Each new digit must record the projected
dimension, numerator-projection rank, and the 91 plane-multiple controls.
Rational reconstruction and global characteristic-zero verification should
begin only after a stable genuine subspace survives enough digits.

Test 0122 performs the first continuation: a carry-aware fifth-digit
calculation has obstruction rank zero and preserves all 568 directions, 477
numerator-bearing directions, and 91 plane controls modulo `19^5`.
