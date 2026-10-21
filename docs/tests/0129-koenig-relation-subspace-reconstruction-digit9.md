# Test 0129: König relation-subspace reconstruction at digit 9

## Question

Does Test 0128's ninth 19-adic digit provide enough effective precision for
entrywise rational reconstruction of the canonical relation-subspace chart?

## Result

No. The modular chart remains exactly coherent through effective precision
`19^6`, but scalar rational reconstruction has plateaued rather than
converged.

```text
source precision   effective chart modulus   mismatches from next level
19^5                                  19^2                            0
19^6                                  19^3                            0
19^7                                  19^4                            0
19^8                                  19^5                            0
19^9                                  19^6                            0
```

At modulus `19^6 = 47,045,881`, the symmetric uniqueness bound is 4,850.
Only 986 of the 1,704 chart entries reconstruct, leaving 718 unresolved.
This is 15 fewer formal successes than at effective precision `19^5`.

Sixty-four reconstructed fractions agree with the preceding level, compared
with 46 in the preceding transition, but no fraction is unchanged across all
five effective precisions. Counts are not expected to be monotone because
the symmetric uniqueness window changes at every level.

The conclusion is methodological: the p-adic subspace is coherent, but
independent scalar reconstruction of its 1,704 chart entries is not extracting
a stable characteristic-zero subspace at the available precision.

## Method

The Sage v3 certificate extends the canonical `568 x 3` chart and entrywise
rational-reconstruction audit through digit nine. The Python checker
independently repeats modular elimination, carry-aware chart lifting, and the
extended-Euclidean reconstruction criterion. It agrees exactly with Sage.
The v1 and v2 historical artifacts remain unchanged and independently
replayable.

## Evidence

Implementation and input revision:
`42571396d5d209cd98c961d42193a342b02e36c2`.

```text
aaba754ab8437e62a2ccfc77cde345184adcd9ef5570ad5f716add409505f928
  data/derived/m23_koenig_a_relation_subspace_reconstruction_digits9.tsv
```

Replay:

```sh
make check-koenig-relation-subspace-reconstruction-digits9
```

## Next gate

Test simultaneous reconstruction before purchasing another full 19-adic
digit. In particular, search for shared denominators or short lattice vectors
across deterministic chart-coordinate subsets, and validate every candidate
against all 1,704 residues and at multiple precisions. Only candidates that
survive those independent gates should be promoted to global exact-identity
checks.

Follow-up: Test 0130 recovers a planted shared denominator but finds no
credible real proposal among 472 deterministic LLL candidates. The best
stabilizes only 126/1,704 entries with support one. Continue through `19^10`
and repeat both scalar and simultaneous audits.
