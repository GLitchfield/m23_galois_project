# Test 0127: König relation-subspace reconstruction at digit 8

## Question

Does Test 0126's extra 19-adic digit provide enough effective precision to
rationally reconstruct the canonical characteristic-zero relation subspace?

## Result

No. The modular subspace remains perfectly coherent, but entrywise rational
reconstruction is still incomplete and unstable.

After eliminating the same rank-three leading obstruction, the canonical
`568 x 3` chart agrees exactly at every shared precision:

```text
source precision   effective chart modulus   mismatches from next level
19^5                                  19^2                            0
19^6                                  19^3                            0
19^7                                  19^4                            0
19^8                                  19^5                            0
```

At effective modulus `19^5 = 2,476,099`, the standard symmetric
rational-reconstruction uniqueness bound is 1,112. It reconstructs 1,001 of
the 1,704 chart entries, leaving 703 unresolved. This is only seven more
successes than at effective precision `19^4`.

The reconstructed fractions are not stable: 46 entries agree between the
last two effective precisions, down from 55 between the preceding pair, and
no reconstructed entry agrees at all four levels. Reconstruction counts need
not be monotone because each level has a different uniqueness bound and a
different residue representative.

Thus the extra digit strengthens the coherent p-adic subspace certificate but
does not yet identify a characteristic-zero chart.

## Method

The Sage implementation extends Test 0125's canonical chart lift through the
new effective digit, applies Sage rational reconstruction to every entry, and
records cross-precision identities and stability counts in a separate v2
certificate.

The Python checker independently repeats modular row reduction, the `3 x 3`
unit-block inversion, all carry-aware chart lifts, and an extended-Euclidean
rational-reconstruction test. It agrees exactly with the Sage certificate.
The original Test 0125 v1 artifact and default replay remain unchanged.

## Evidence

Implementation revision:
`66b35d1baada4bdfc4d8b619024e486416f08291`.

```text
ee3da3070ef2ffeb60ac30a6f15e6dea963d69dcfea7bc669cb71ee1cfdf605a
  data/derived/m23_koenig_a_relation_subspace_reconstruction_digits8.tsv
```

Replay:

```sh
make check-koenig-relation-subspace-reconstruction-digits8
```

## Next gate

Continue the complete homogeneous relation subspace through `19^9`. This
would supply effective chart precision `19^6 = 47,045,881` and raise the
symmetric reconstruction bound to 4,850. The full modulus
`19^9 = 322,687,697,779` still fits the solver's current `uint64` storage;
exact digit-convolution products remain required.

Follow-up: Test 0128 finds obstruction rank zero at digit nine, preserving
all 568 directions, 477 numerator-bearing directions, and 91 controls.
Repeat this reconstruction audit at effective precision `19^6`.
