# Test 0036: exact 5A maximal-subgroup generation masks

## Question

Can fixed-first 5A tuple generation be replaced exactly by a compact incidence
test suitable for native CPU and bulk GPU kernels?

## Inputs and provenance

- M23 in its natural degree-23 action;
- 5A class size 680,064;
- schema-v2 5A pair checkpoint SHA-256
  `1d6653fedb4327ed4594a1ca55cad03b82fbcae5a45817dbadeede05902468ea`;
- GAP 4.12.1;
- first nonidentity macroblock in each of the 16 product classes.

## Exact reduction

For a fixed 5A target `t`, GAP enumerates every conjugate of every maximal
subgroup class that contains `t`. Each count is independently checked by

```text
[G:N_G(H)] * |5A intersect H| / |5A|.
```

The seven maximal-subgroup classes contribute respectively
`3,3,3,1,3,1,0` conjugates, for exactly 14 relevant subgroups. Assigning one
bit to each subgroup gives every 5A element a 14-bit mask. A normalized tuple
`(t,g2,g3,g4)` is nongenerating exactly when all four masks share a bit: every
proper subgroup is contained in a maximal subgroup, and the shared subgroup
must be one of the 14 containing `t`.

The checked subgroup census is in
`data/reference/m23_5a_generation_mask_certificate.tsv`.

## Differential validation

The first block from every nonidentity product class contains 3,089 relative
representatives. Direct GAP group generation classified 1,626 as generating.
The mask criterion also classified 1,626 as generating, with zero
disagreements and 54 distinct masks in the validation slice.

The full exporter writes one little-endian 16-bit mask in exactly the same
680,064-row order as the native coordinate checkpoint. The resulting payload
is 1,360,311 bytes including provenance metadata and an ordered target-row
fingerprint. It contains 256,284 nonzero rows and 62 distinct masks. C++ checks
that fingerprint against the complete target-pair table and reproduces the
1,626/3,089 validation census.

Reproduce the compact certificate with:

```bash
make check-5a-generation-masks
```

Generate and check the full operational table with:

```bash
scripts/generate-5a-generation-masks.sh runs/5a-generation-masks.bin
scripts/check-native-generation-masks.sh \
  runs/5a-coordinate-tables-cbb8ab9.bin runs/5a-generation-masks.bin
```

The coordinate path may point to any compatible 5A global checkpoint; the
checker requires matching pair-checkpoint provenance.

## Verdict and limit

Passed as an exact generation predicate and native checkpoint seam. Generation
was about 10.5 percent of the measured cold 5A block kernel, so this is a
useful low-risk optimization and GPU prerequisite, not by itself a solution to
the full traversal runtime.
