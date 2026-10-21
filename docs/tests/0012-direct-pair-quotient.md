# Test 0012: direct pair-twist quotient

## Question

Can relative double-coset coordinates locate pure-braid images without repeated
whole-tuple canonicalization, including noncyclic and identity product
centralizers, and does the resulting weighted quotient preserve a known pure
component exactly?

## Method

Build pair-transporter lookups inside each proper product centralizer. Refine a
macroblock by the actions of the two internal pair twists, expressed in its
relative double cosets. Treat the identity-product macroblock separately as the
10,099 double cosets of the target centralizer in M23.

Compare direct and canonical pair-twist partitions for sampled product orders
4, 5, 6, 7, 8, 11, 14, 15, and 23. Exercise direct-only noncyclic cases of
orders 2 and 3. Compare all outgoing refined edges of a sampled order-11 vertex
with the canonical macroblock locator. Finally, traverse from the translated
known 4A seed, contracting the internal pair-twist action and summing vertex
weights.

## Result

- direct coordinates biject every sampled materialized macroblock;
- the identity block has 10,099 singleton pair-twist vertices;
- direct and canonical cyclic refinements agree exactly;
- both edge implementations find the same 22 destination macroblocks;
- 484 quotient vertices close and have total weight 2,456.

The quotient is exact. The initial development-machine run took about 124
seconds after locator construction. Retaining fixed-pair normalizers in
checkpoint schema 2 reduces the identical traversal to about 14.2 seconds. This
test does not claim complete 4A coverage.

## Reproducibility record

- baseline revision: `9a9039e`; implementation is the commit containing this
  note;
- GAP 4.12.1, AtlasRep 2.1.8, CTblLib 1.3.7;
- input: a verified 4A pair checkpoint and the first representative in the
  verified 4A bridge shard;
- commands: `scripts/gap/check_direct_pair_coordinates.g` and
  `scripts/gap/probe_direct_pair_quotient.g`.
