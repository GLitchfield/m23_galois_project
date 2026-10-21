# Test 0091: exact degree-28 recognition of the class-1 8A Belyi map

## Question

Can the test-0090 numerical endpoint be recognized in a bounded number field,
substituted into the defining equations exactly, and pass an independent exact
ramification check?

## Degree and height gates

The rational passport contains exactly 28 generating inner classes. The
normalization `(1,4,2)` uses the uniquely distinguished multiplicity-1,
multiplicity-4, and multiplicity-2 points in the first fibre, so it introduces
no arbitrary choice among equal ramification points. GAP also computes the
centralizer of the recovered monodromy group in `S23` to have order one, so
the cover has no nontrivial automorphism. This gives degree 28 as the natural
hard ceiling for the normalized coefficient field.

The recognition probe therefore searched only through degree 28. It did not
reuse the earlier exploratory degree-112 relations. The committed run used:

- an 8,192-bit Newton refinement for training;
- an independently recomputed 16,384-bit refinement for validation;
- training precisions 2,048, 4,096, and 8,000 bits;
- coefficient-height ceilings 128, 160, 192, 224, and 256 bits; and
- a required holdout gain of at least 1,024 bits beyond training.

The two refinements agree by at least 8,150 bits over all 23 coefficients.
Eight coefficient names produce stable degree-28 minimal-polynomial
candidates. Repeated discoveries at larger height bounds account for the 22
accepted grid rows. Their validation residuals are about 16,320 bits rather
than merely the 8,000 training bits.

## Common-field recovery

The degree-28 relation for `c2` defines the initial field. A seeded Sage
optimization replaces its poorly conditioned power basis by the much smaller
reciprocal polynomial

```text
T^28 - 12*T^27 + 66*T^26 - 216*T^25 + 467*T^24 - 724*T^23
+ 1040*T^22 - 2244*T^21 + 6365*T^20 - 15960*T^19
+ 32494*T^18 - 54820*T^17 + 78675*T^16 - 97416*T^15
+ 104584*T^14 - 97416*T^13 + 78675*T^12 - 54820*T^11
+ 32494*T^10 - 15960*T^9 + 6365*T^8 - 2244*T^7 + 1040*T^6
- 724*T^5 + 467*T^4 - 216*T^3 + 66*T^2 - 12*T + 1.
```

For the individually recognized coefficients, exact number-field
isomorphisms select the embedding matching the 16,384-bit values. For the
remaining coefficients, integer-relation recovery in the optimized basis is
run independently at 4,096 and 8,000 bits. Every one of the 23 coordinates:

- returns the same relation at both training precisions;
- stays within the predeclared 256-bit coordinate-height ceiling when lattice
  recovery is used; and
- has at least 16,315 normalized validation-residual bits.

Substitution in the coefficient ring of the degree-28 field gives the exact
polynomial identity

```text
P(x) + F(x) = Q(x).
```

This is literal equality in the number-field polynomial ring, not a numerical
residual.

## Independent exact verification

`scripts/verify_belyi_candidate_sage.sage` consumes only the versioned exact
candidate JSON. It reuses the established schema and provenance intake, asks
GAP to prove the defining polynomial irreducible over `Q`, then independently
constructs the number field and rational function in Sage. Native exact
polynomial gcd and squarefree-layer computations prove:

```text
degree                 23
coefficient-field degree 28
field irreducibility   verified by GAP 4.12.1
fibre over 0           (8,8,4,2,1)
fibre over 1           (8,8,4,2,1)
fibre over infinity    (2,2,2,2,2,2,2,2,1,1,1,1,1,1,1)
Riemann--Hurwitz sum   44
```

The numerator and denominator are coprime. No numerical roots or root
clustering enter this verification.

## Result and scope

Pass as an **exact degree-23 Belyi map over an irreducible degree-28 number
field** with the target `8A/8A/2A` ramification.

Test 0090 supplied the first separate cover-monodromy evidence: doubled-mesh
high-precision loop lifting produced finite permutations generating `M23` and
matching inner class 1 uniquely. The exact candidate is the algebraic
recognition of that same numerical embedding to more than 8,000 common bits.
Test 0092 subsequently replaced the numerical path link with a rigorous
interval continuation of the exact coefficients and recovered `M23`, inner
class 1.

This is not an `M23/Q` realization. The displayed map is defined over a
degree-28 coefficient field, and a non-Galois Belyi cover over a number field
does not by itself produce a regular `M23` extension of `Q`.

## Reproduction

```sh
./scripts/run-8a-sage.sh --python \
  scripts/refine_8a_belyi_candidate.sage \
  data/derived/m23_8a_barth_wenz_domain2_certified_endpoint-path1.tsv \
  --precision-bits 8192 --maximum-iterations 20 \
  --output /tmp/m23_8a_coefficients_8192.tsv
./scripts/run-8a-sage.sh --python \
  scripts/refine_8a_belyi_candidate.sage \
  data/derived/m23_8a_barth_wenz_domain2_certified_endpoint-path1.tsv \
  --precision-bits 16384 --maximum-iterations 20 \
  --output /tmp/m23_8a_coefficients_16384.tsv
./scripts/run-8a-sage.sh --python \
  scripts/probe_8a_algebraic_recognition.sage \
  /tmp/m23_8a_coefficients_8192.tsv \
  /tmp/m23_8a_coefficients_16384.tsv \
  --max-degree 28 --training-bits 2048,4096,8000 \
  --height-bits 128,160,192,224,256 --minimum-holdout-bits 1024 \
  --output /tmp/m23_8a_recognition_probe.tsv
./scripts/run-8a-sage.sh --python \
  scripts/recover_8a_number_field.sage \
  /tmp/m23_8a_coefficients_8192.tsv \
  /tmp/m23_8a_coefficients_16384.tsv \
  /tmp/m23_8a_recognition_probe.tsv \
  --generator c2 --generator-height-bits 128 \
  --training-bits 4096,8000 --maximum-coordinate-height-bits 256 \
  --minimum-holdout-bits 1024 --optimization-seed 20260723 \
  --output /tmp/m23_8a_number_field_recovery.tsv \
  --candidate-output /tmp/m23_8a_exact_candidate.json
./scripts/run-8a-sage.sh --python \
  scripts/verify_belyi_candidate_sage.sage \
  /tmp/m23_8a_exact_candidate.json
make check-8a-exact-recognition
```

## Evidence

- `data/derived/m23_8a_belyi_class1_high_precision_coefficients_8192.tsv`;
- `data/derived/m23_8a_belyi_class1_high_precision_coefficients_16384.tsv`;
- `data/derived/m23_8a_belyi_class1_recognition_probe.tsv`;
- `data/derived/m23_8a_belyi_class1_number_field_recovery.tsv`;
- `data/derived/m23_8a_belyi_class1_exact_candidate.json`;
- `scripts/probe_8a_algebraic_recognition.sage`;
- `scripts/recover_8a_number_field.sage`;
- `scripts/check_8a_exact_recognition.py`; and
- `scripts/verify_belyi_candidate_sage.sage`.
