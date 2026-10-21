# Test 0132: König relation-subspace reconstruction at digit 10

## Question

Does Test 0131's tenth 19-adic digit provide enough effective precision for
entrywise rational reconstruction of the canonical relation-subspace chart?

## Result

No. The modular chart remains exactly coherent through effective precision
`19^7`, but scalar rational reconstruction still does not converge.

```text
source precision   effective chart modulus   mismatches from next level
19^5                                  19^2                            0
19^6                                  19^3                            0
19^7                                  19^4                            0
19^8                                  19^5                            0
19^9                                  19^6                            0
19^10                                 19^7                            0
```

At modulus `19^7 = 893,871,739`, the symmetric uniqueness bound is 21,140.
Only 981 of the 1,704 chart entries reconstruct, leaving 723 unresolved.
This is five fewer formal successes than at effective precision `19^6`.

Forty-seven reconstructed fractions agree with the preceding level, compared
with 64 in the preceding transition, and no fraction is unchanged across all
six effective precisions. Counts are not expected to be monotone because the
symmetric uniqueness window changes at every level.

The conclusion is methodological: the p-adic subspace remains exactly
coherent, but independent scalar reconstruction of its chart entries is not
revealing a stable characteristic-zero subspace even after another factor of
19 in effective precision.

## Method

The Sage v4 certificate extends the canonical `568 x 3` chart and entrywise
rational-reconstruction audit through digit ten. The last chart-lifting stage
exceeds the safe one-shot `uint64` dot-product bound, so both the producer and
independent Python checker use explicit bounded-width modular products. The
digit-9 v3 certificate remains unchanged under this arithmetic.

The Python checker independently repeats modular elimination, carry-aware
chart lifting, and the extended-Euclidean reconstruction criterion. It agrees
exactly with Sage. The v1--v3 historical artifacts remain unchanged and
independently replayable.

## Evidence

Implementation and input revision:
`4053b0e72dc5ffcb8b68c7f14ba0c06e37ce8778`.

```text
aa0e871b104dcd3f59ba354ed59389a54c18760b37952e7d4fddf56671f46c87
  data/derived/m23_koenig_a_relation_subspace_reconstruction_digits10.tsv
```

Replay:

```sh
make check-koenig-relation-subspace-reconstruction-digits10
```

## Next gate

Repeat Test 0130's deterministic simultaneous LLL projections at effective
precision `19^7`. Compare all-coordinate and cross-precision stability against
the earlier 472-candidate distribution. A genuine shared denominator should
improve sharply after the extra factor of 19; another random-scale result
would close the current bounded reconstruction strategy.
