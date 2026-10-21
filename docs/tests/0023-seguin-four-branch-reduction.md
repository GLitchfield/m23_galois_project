# Test 0023: Seguin four-branch reduction

## Question

What concrete Nielsen tuple underlies Seguin's 2025 existence result for a
four-branch component of connected `M23`-covers defined over `Q`, and is it a
new homogeneous braid-search space?

## Method

Transcribe the permutations `a` and `h` printed in Example 5.5 of Seguin's
paper and set `b = h^-1*a*h`, exactly as in the paper's GAP snippet. Verify
independently in GAP that `a` and `b` have order 3, generate the natural
`M23`, and that

```text
(a, a^-1, b, b^-1)
```

is a product-one generating tuple entirely in the rational class `3A`.
Compare its ambient Nielsen class with Häfner's completed `(3A)^4`
calculation.

## Result

The transcription passes all group-theoretic checks. The `3A` class has
56,672 elements and centralizer order 180. Seguin's four-branch construction
therefore lands inside `(3A)^4`, whose 37,296 generating inner classes were
already reported by Häfner to split into two complete braid orbits of sizes
8,316 and 28,980. Their symmetric genera are respectively 325 and 1,206.

This changes the interpretation of the Seguin direction. It is not presently
a third unfinished homogeneous enumeration comparable to `5A`; it is a
field-of-definition and rational-point problem on marked components lying over
an already enumerated high-genus inner Nielsen space. The paper's
nonconstructive conjugator does not identify the marked component or provide
equations.

Test 0099 now resolves the marked/inner distinction for connected tuples:
Seguin's Proposition 2.4(iv) makes the component map bijective.  It also
places the printed `h` tuple in the 28,980-class component and proves that
both full components are defined over `Q`.  Neither result supplies equations
or a rational point.

## Reproducibility

```bash
./scripts/check-seguin-example.sh
```

Expected output is stored in
`data/reference/seguin_2025_m23_example.tsv`.

Primary source: Béranger Seguin, *Fields of Definition of Components of
Hurwitz Spaces*, Example 5.5, accepted for publication in 2025,
<https://doi.org/10.2422/2036-2145.202310_013>.
