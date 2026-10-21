# Test 0120: König degree-110 digit-4 gate

## Question

Do the 545 denominator monomials of total degree 106--110 from the original
recovery ansatz remove the cutoff-105 obstruction and lift the recovered
relation from modulo `19^3` to modulo `19^4`?

## Result

No. The complete normalized degree-110 system has the independently
recomputed structure

```text
unknowns:       15,721
rank modulo 19: 15,151
gauge dimension:   570
```

The valid cutoff-105 coefficient vector modulo `19^3 = 6,859` remains a
solution after the extra coordinates are inserted as zero. Its digit-4
correction uses 378 of the 545 restored high-degree denominator coordinates,
but exhaustive residual checks give

```text
modulus 19^4 = 130,321
fitting residuals: 799 of 16,000
holdout residuals: 368 of 384
```

This rejects every digit-4 correction of the committed mod-`19^3` seed. It is
not merely a rejection of one digit-4 gauge choice: the 15,151 pivot rows span
the training row space. Any alternative digit-4 correction of that fixed seed
differs by an element of the 570-dimensional mod-19 kernel and therefore has
the same residual on every training row.

It does **not** yet reject every degree-110 relation modulo `19^4`. The seed
inherits arbitrary gauge choices at digits 2 and 3, and the 545 restored
degree-106--110 coordinates were fixed to zero at those lower digits. In an
underdetermined system over `Z/19^4`, a different mod-`19^3` representative
can lift even when the selected representative does not. A seed-independent
claim requires the full homogeneous kernel over `Z/19^4`, or an equivalent
strong-echelon/Howell solvability certificate.

The smaller residual count relative to Test 0119 (`869` fitting residuals)
and the 378 active restored coordinates show that the added terms matter, but
they do not remove this seed's obstruction. The mixed local family itself
remains fully certified; the seed-independent degree-110 existence question
remains open.

No rejected coefficient vector is committed. The summary records its digest
for production-run diagnostics, while guarded output prevents it from being
published as a valid relation. The row and column profiles are committed so
the rank/gauge calculation and later ansatz expansions have stable indices.

## Evidence

Implementation revision:
`4a69803d031787de2f52b3299b8b1d0112e4515d`.

```text
1d383440df1dc3fc8297260b3e1ce8b824bdb0bb6f6a7bc1128114eebfb1f9bc
  data/derived/m23_koenig_a_relation_degree110_digit4.tsv
032fa38ed91e71b76a60b031702f37da176e8834eef8df9849b01b0b4f51959a
  data/derived/m23_koenig_a_relation_degree110_profiles.tsv
```

The production run used Sage 10.9, took 16 minutes 25.62 seconds wall time,
and reached 3,488,040 KiB maximum RSS. The heavy reproduction target rebuilds
the mixed family, matrix, profiles, correction, and all 16,384 residuals;
the default lightweight checker validates the committed provenance, indices,
digests, dimensions, and rejection outcome.

## Corrected next gate

Compute the complete homogeneous `16,000 x 15,722` relation kernel over
`Z/19^4`, without the `P[0,1]=1` normalization. The mod-19 kernel must have
dimension 571, including all 91 exact plane-equation multiples.

- **Pass:** a unit-content relation with nonzero numerator projection survives
  modulo `19^4` and vanishes on all 384 holdouts.
- **Fail:** the full kernel certificate shows that only plane multiples (or
  relations with numerator divisible by 19) survive.

This closes both the lower-digit gauge loophole and the normalization loophole
before any larger monomial shell is attempted.

Test 0121 subsequently runs this gate. It finds that the old mod-19 direction
is genuinely obstructed, but 568 of 571 alternative directions survive
through `19^4`, including 477 numerator-bearing relations.
