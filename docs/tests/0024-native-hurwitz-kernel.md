# Test 0024: native permutation and Hurwitz kernel

## Question

Can a compact C++ representation reproduce GAP's degree-23 permutation and
braid conventions exactly before any search logic is ported?

## Method

Use Seguin's explicit generating `3A` pair to form the product-one tuple
`(a,a^-1,b,b^-1)`. Generate ordinary Hurwitz, inverse Hurwitz, and direct pure
braid images in GAP as one-line degree-23 permutations. Compile the C++ kernel
with warnings as errors and compare all native outputs with the frozen GAP
fixture. Independently compare each direct pure move with its Hurwitz word.

## Result

The native kernel agrees coordinate-for-coordinate with GAP for all fixture
moves. Ordinary and inverse Hurwitz actions cancel, the three direct formulas
agree with their braid words, and every tested action preserves product-one.
The packed native permutation occupies 23 bytes.

This validates only the lowest-level convention boundary. It does not yet
validate macroblock refinement, direct relative coordinates, graph traversal,
or native certificate production.

## Reproducibility

```bash
make check-native-kernel
```

The command regenerates `data/reference/native_kernel_fixture.tsv` with GAP,
compares it with the committed fixture, compiles the C++ test in a temporary
location, and runs it.
