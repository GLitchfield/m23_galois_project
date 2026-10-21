# Test 0105: König finite-field anchor and family inputs

## Question

Can the published finite-field cover be linked exactly to the archived
`(alpha,beta)` plane equation, and is the released 980-vector fiber enough to
reconstruct the moving tautological family?

## Primary-source scope

König's dissertation, Chapter 5.3, states that the 980 archived complex
vectors are the complete fiber above `a=1/4` of the degree-980 Hurwitz cover.
It then says that separate `19`-adic lifts were used to find the
bidegree-`(97,98)` dependency. The dissertation also says that, in the
mod-19 family, `a` and every coefficient of `f1,f2,g1,g2,C` were expressed as
polynomials in `alpha,beta`.

Those finite-field coefficient expressions, the moving `19`-adic lifts, and
the rational-reconstruction transcript are not present in the released
archive. The archive contains the single complex fiber, the plane equation,
and related approximation files.

This distinction matters. Values of a rational function at one finite fiber
do not determine it on the curve: a candidate can be changed by a multiple of
the nonzero function `a-1/4` without changing any of those 980 values.
Consequently, higher precision or unconstrained interpolation of this one
fiber cannot prove a component-wide tautological family.

## Exact finite-field anchor

Run:

```sh
make check-koenig-f19-anchor KOENIG_ARCHIVE=/path/to/archive.zip
```

`scripts/verify_koenig_f19_anchor.sage` authenticates the official archive
through the existing SHA-256 gate and reconstructs the explicit cover printed
on dissertation page 73 over `F_19`.

The exact target change

```text
T = 10*t + 5
```

sends its order-three branch value to `1/4=5`, its order-two branch values
`9,11` to `0,1`, and leaves the order-five value at infinity. Factoring the
four fibers over `F_19` verifies the geometric ramification partitions

```text
(2^8.1^7, 2^8.1^7, 3^6.1^5, 5^4.1^3).
```

The exact source change

```text
X = 5*Y + 2
```

puts the two monic cubic denominator factors in the thesis normalization:
their `Y^2` coefficients become `1/3` and `-1/2`. The resulting normalized
factors have

```text
alpha = coefficient(f2,Y^4) = 7,
beta  = coefficient(f1,Y^5) = 14,
C = 14
```

in `F_19`. Exact evaluation of the authenticated plane equation gives

```text
h(7,14) = 0 mod 19.
```

This is an exact incidence anchor between the published cover and the plane
coordinates. It does not prove that the full characteristic-zero braid
component maps to the plane curve.

## Refined stopping artifact

The smallest primary artifact that would materially advance the exact
component bridge is now:

1. the mod-19 polynomial expressions for `a,f1,f2,g1,g2,C` in
   `alpha,beta`, with their normalization;
2. code verifying the normalized cover identities in
   `Frac(F_19[alpha,beta]/(h mod 19))`;
3. the moving `19`-adic lift samples or scripts used at precision
   `19^100000`; and
4. the dependency/rational-reconstruction transcript that produces the exact
   characteristic-zero equation and coefficient relations.

With item 1, the repository can first reproduce the finite-field
component-wide map independently. Items 2--4 are needed to turn that modular
map into the preferred characteristic-zero tautological-family certificate
from Test 0104. If the original material is unavailable, an independent
reimplementation must generate moving finite-field or `19`-adic fibers; the
released `a=1/4` fiber alone is not a sufficient input.
