# Test 0111: König generic mod-19 passport

## Question

Do the global rational functions certified in Tests 0109 and 0110 define a
nondegenerate degree-23 cover with the intended four branch partitions over
the mod-19 plane function field?

## A defined, nondegenerate fiber

The translated plane point

```text
(u,v) = (2,11),  (alpha,beta) = (9,6)
```

lies on the irreducible plane equation modulo 19. The Test 0109 common
denominator is `D=6` there, so every recovered rational function is defined.
The other parameters are

```text
a = 1,  lambda = 1,  C = 12.
```

The specialized monic factors are

```text
f1 = X^6 + 6X^5 + 15X^4 + 18X^3 + 6X^2 + 4X + 8,
f2 = X^5 + 9X^4          + 17X^2 + 18X   + 15,
g1 = X^3 + 13X^2 + 6X + 11,
g2 = X^3 +  9X^2 + 11X + 9.
```

All four self-resultants with their derivatives are nonzero:

```text
Res(f1,f1')=2,  Res(f2,f2')=16,
Res(g1,g1')=3,  Res(g2,g2')=12.
```

All six pairwise resultants are also nonzero:

```text
Res(f1,f2)=3,   Res(f1,g1)=16,  Res(f1,g2)=4,
Res(f2,g1)=2,   Res(f2,g2)=15,  Res(g1,g2)=14.
```

Thus the numerator and denominator factors are separable and pairwise
coprime at this point.

## Exact branch audit

Write

```text
F = f1^3 f2,  G = g1^5 g2,  t = C F/G.
```

The exact specialized fibers have geometric root-multiplicity partitions

```text
t=0:         3^6 1^5,
t=4:         2^8 1^7,
t=6:         2^8 1^7,
t=infinity:  5^4 1^3.
```

The fourth order-five point is `X=infinity`, because `deg(F)-deg(G)=5`.
The ramification excess is

```text
6(3-1) + 8(2-1) + 8(2-1) + 4(5-1) = 44 = 2*23-2.
```

The residual critical polynomial has degree 16 and separability resultant
one. Exact derivative factorization gives

```text
(CF)'G - (CF)G' = C f1^2 g1^4 R.
```

Test 0110 globally proved that `R` divides the product of the two quadratic
branch fibers. At this point,

```text
deg gcd(R, CF-4G) = 8,
deg gcd(R, CF-6G) = 8.
```

This independently checks the required `8+8` distribution.

## Why this certifies the generic passport

The mod-19 plane is irreducible, so its coordinate ring has a function
field. A resultant that specializes to a nonzero value at a point where the
rational family is defined is nonzero in that function field. The displayed
values therefore prove generic separability and pairwise coprimality.

Over the quadratic extension obtained by adjoining `lambda` with
`lambda^2=a`, the two residual fibers are

```text
CF-(5+lambda)G  and  CF-(5-lambda)G.
```

They are generically coprime: their difference is `-2 lambda G`, while `F`
and `G` are coprime and `a,C` are nonzero. Test 0110 makes the squarefree
degree-16 residual factor divide their product. Specialized gcd degree can
only increase; the exact `8+8` fiber therefore bounds both generic gcd
degrees by eight. Since they sum to 16, both generic degrees equal eight.
The nondegenerate specialization also rules out higher residual
multiplicities. Hence the generic cover has exactly the stated passport.

## Evidence and replay

The implementation revision is
`b55af2a83686412dfb7255d6594b55d39cc8e6d2`. The compact certificate is
`data/derived/m23_koenig_f19_passport_point.tsv`, with SHA-256

```text
eb87dca7e9b8723b9d8ab60649adaf2c01a482a1b39ffc264a55b58468668fca.
```

It binds the family, Test 0110 certificate, authenticated archive, code
revision, Sage version, exact factors, every resultant, partitions, derivative
identity, and Riemann--Hurwitz total. Replay it with:

```sh
make check-koenig-f19-passport \
    KOENIG_ARCHIVE=/path/to/Polynomials_And_Approximation_Data.zip
```

## Consequence and remaining boundary

The project now has an explicit rational degree-23 family over the mod-19
plane function field with the intended generic passport. This closes the
finite-characteristic coefficient and branch-structure reconstruction gate.

It is not yet an `M23/Q` polynomial. The recovered coefficient functions are
only modulo 19, and a passport alone does not independently identify the
generic monodromy group. The next work should pin the `C2`
quotient-to-cover/component identification, audit monodromy independently
where practical, and then reconstruct or lift the family in characteristic
zero before searching for rational interior specializations.
