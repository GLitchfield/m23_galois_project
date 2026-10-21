# Test 0116: König relation-lift rigidity gate

## Question

Does the recovered mod-19 support determine a unique normalized lift target,
and can its coefficients be lifted by merely choosing small integer
representatives?

## Exact support audit

The selected relation for `a=lambda^2` has 5,252 nonzero numerator
coefficients and 5,322 nonzero denominator coefficients. The stored
cutoff-105 recovery basis contains 50 independent relations with nonzero
numerator projection.

The remaining kernel freedom is reconstructed independently from König's
plane equation. After shifting to `u=alpha-7`, `v=beta-14`, its 36 monomial
multiples through total degree 105 are linearly independent and disjoint from
the 50 stored rows. Thus the complete cutoff-105 relation space has dimension
86.

Restricting only the numerator to the candidate support leaves dimension 37.
Restricting both numerator and denominator to the candidate's full nonzero
support leaves

```text
dimension 1, numerator rank 1.
```

The coefficient of `v` in the numerator is `1 mod 19`; fixing it to exactly
one removes the scalar freedom. Consequently the normalized support matrix
has inferred rank

```text
5,252 + 5,322 - 1 = 10,573.
```

This proves uniqueness inside the fixed support. It does not prove that a
lift exists there: coefficients that vanish modulo 19 could become nonzero
in characteristic zero, and inconsistency can appear on non-pivot equations.
The production lift must therefore check every series row after every
p-adic correction.

## Centered-lift falsification

Lifting each nonzero mod-19 coefficient to its representative in `[-9,9]`
does not solve the characteristic-zero relation. Over
`(Z/19^4 Z)[s]/(s^64)`, all 64 residual coefficients remain nonzero:

```text
19-adic valuation 1: 60 coefficients
19-adic valuation 2:  3 coefficients
19-adic valuation 3:  1 coefficient.
```

Thus genuine coefficient linear algebra is required beginning at the second
19-adic digit.

## Solver decision

A side-by-side Fable/Codex review agreed that the appropriate next pilot is
the real 10,573-column normalized system, not a reduced toy. It should:

1. select pivots only from the first 16,000 fitting rows;
2. preserve the final 384 rows as a holdout;
3. compute one reusable word-sized modular factorization;
4. lift only through `19^4` initially; and
5. require zero residual on all 16,384 rows after every correction.

Support rigidity supplies uniqueness; these full-row residual checks supply
the missing existence test. Polynomial approximant bases do not match the
remaining scalar-unknown problem, while black-box Wiedemann is not favored
for this dense matrix. Quotient-ring arithmetic remains appropriate for the
later global identity check.

## Evidence

Implementation revision:
`974eb08c7e0cabd9223983361ce716c0372c6224`.

```text
29f3b43fa76954f8c1891d72b9315a28ee874114c9c4f51f14d20474baeb108a
  data/derived/m23_koenig_relation_lift_space.tsv
a92a9f43651e62a9437682a4c6f9c56a3b314b9ce7ec8678083f36aafdb161b2
  data/derived/m23_koenig_a_centered_lift_probe.tsv
```

The full archive-backed replay is:

```sh
make check-koenig-relation-lift-gates \
    KOENIG_ARCHIVE=/path/to/Polynomials_And_Approximation_Data.zip
```
