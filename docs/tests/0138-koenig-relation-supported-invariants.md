# Test 0138: König supported numerator invariants

## Question

What is the basis-independent local Smith profile of the exact
beta-degree-at-most-77 numerator image modulo `19^10`, and what caused the
chart incoherence in Test 0137?

## Result

The image has seven unit invariant factors and exactly three additional
19-divisible factors, all at valuation 7:

```text
valuation 0: 7 factors with annihilator exponent 10
valuation 7: 3 factors with annihilator exponent 3
```

Equivalently, as a finite `Z_19`-module at the available precision, the
80-generator image is

```text
(Z/19^10 Z)^7  +  (Z/19^3 Z)^3.
```

There are ten nonzero Smith factors and 70 zero factors. Its length over
`F_19` is `7*10 + 3*3 = 79`.

This gives a precise explanation of Test 0137. The mod-19 image sees only the
seven unit directions. Three more directions are invisible modulo 19 because
their numerator coefficients are divisible by `19^7`, but they are nonzero
modulo `19^10`. Changing a seven-row complement by these short factors shifts
higher chart digits without changing the mod-19 quotient.

Thus the exact image is not a saturated free rank-seven submodule at the
current finite precision. The obstruction is nevertheless very small and
structured: it is three copies of order `19^3`, not a broad higher-rank
failure.

## Method

The Sage producer reconstructs the exact `80 x 7566` supported numerator image
from the complete homogeneous pivot transformation. A local Smith reduction
then works valuation by valuation:

1. select a maximal unit pivot block modulo 19;
2. invert that block modulo the current power of 19;
3. remove it with an exact Schur complement;
4. verify that the residual is divisible by 19; and
5. divide by 19 and continue.

All products use exact base-19 convolution, so no `uint64` or floating-point
roundoff enters the result.

The planted gate starts with invariant valuations `0,1,3`, applies a nontrivial
unimodular row change and column permutation, and recovers the same profile.

The independent Python checker uses its own modular elimination, digitwise
unit-block inverse, Schur reduction, and base-19 product. It verifies the
complete saved numerator image, ties its mod-19 reduction back to the
committed 80-vector supported basis and numerator map, and independently
recovers valuations `0^7,7^3`.

The official SageMath 10.9 run took 23 minutes 6.82 seconds with maximum RSS
13,825,812 KiB. The independent replay took 0.82 seconds with maximum RSS
131,320 KiB.

## Evidence

Production revision:
`cc28796e7b3d0c7f51040f2fab99fcbbf0303fb7`.

```text
16a44ac3959200c9039b5bdb6249c65cf42e3bd122be3b2ff1b374ca4f0d2efb
  data/derived/m23_koenig_a_relation_supported_beta77_invariants_digits10.tsv
efc9e8e8e7e31e2816141572107e6b1bfed73234f41a492c247db1949894e33a
  data/derived/m23_koenig_a_relation_supported_beta77_numerator_image_digits10.npz
```

Replay:

```sh
make check-koenig-relation-supported-invariants
```

## Next gate

Test 0139 computes the actual profile at every digit from 4 through 10. The
three short factors do have constant order `19^3`: their valuations retreat
from 1 through 7, so they disappear in the inverse limit and leave a free
rank-seven `Z_19` image. Next construct a compatible quotient by the bounded
transient directions and resume rational reconstruction on its coherent
rank-seven chart.
