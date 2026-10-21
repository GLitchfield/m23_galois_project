# Test 0090: high-precision refinement and M23 cover monodromy

## Question

Does the certified domain-2 endpoint refine in the exact coefficient
presentation, and does its degree-23 rational function numerically recover the
intended `M23` inner class rather than merely an ambient passport solution?

## High-precision coefficient refinement

`scripts/refine_8a_belyi_candidate.sage` constructs the 23 coefficient
equations over `QQ` for normalization `(1,4,2)`. It converts the certified
root endpoint into the monic quadratic and degree-8/degree-7 factor
coefficients, forms the exact symbolic Jacobian, and applies Newton iteration
over Sage's arbitrary-precision complex field.

At 4096 bits, eight Newton steps reduced the maximum coefficient residual to
approximately `5.09e-1231`. The committed artifact records more than 1,000
decimal digits for every real and imaginary component, its source hash, Sage
10.9, the code revision, and the exact chart. These remain numerical
coefficients, not recognized algebraic numbers.

## Cover-loop lifting

At basepoint `1/2`, the 23 roots of `P(x) - (1/2)Q(x)` were ordered
deterministically. Standard counterclockwise circles of radius `1/2` around
`0` and `1` were lifted by predictor-corrector continuation at 256-bit
precision.

The calculation was performed first with 512 steps per loop and then with
1,024. Both meshes returned identical permutations. The fine-mesh diagnostics
were:

| diagnostic | loop around 0 | loop around 1 |
| --- | ---: | ---: |
| maximum polynomial residual | `9.88e-64` | `5.47e-66` |
| minimum root separation | `0.003568` | `0.002711` |
| minimum derivative magnitude | `8.81e-15` | `8.81e-15` |
| endpoint matching error | `2.88e-70` | `6.04e-70` |

The recovered cycle partitions are

- around `0`: `(8,8,4,2,1)`;
- around `1`: `(8,8,4,2,1)`; and
- around infinity: `(2^8,1^7)`.

The three recorded permutations satisfy product one exactly as finite
permutations.

## Independent group and class checks

`scripts/check_8a_cover_monodromy.py` does not use the numerical lifting code.
It:

1. reconstructs and checks the three permutations and their passport;
2. asks GAP to compute the generated transitive group;
3. obtains order `10,200,960` and structure description `M23`;
4. checks simultaneous conjugacy against all 28 committed generating inner
   classes; and
5. finds exactly class 1.

The explicit relabeling from numerical sheets to the class-1 ledger is:

```text
13,17,16,22,15,7,19,4,20,3,2,8,5,10,1,11,21,12,18,9,14,23,6
```

This exact finite-permutation check distinguishes the endpoint from the large
ambient `S23` passport population.

## Result

Pass as a **high-precision numerical Belyi map with independently identified
cover monodromy `M23`, in certified inner class 1**. Together with test 0089,
the project now has:

- a certified isolated endpoint of the represented numerical root system;
- 4096-bit coefficient refinement of the exact symbolic equations;
- stable numerical lifting of the cover loops;
- exact finite-permutation group identification as `M23`; and
- an explicit unique match to the intended class-1 triple.

This still is not an exact algebraic Belyi equation. Loop lifting is numerical,
and the 4096-bit coefficients have not been recognized in a number field.
The next gate is exact algebraic recognition followed by the existing exact
ramification verifier. Until then, this result must not be described as an
exact map or as an `M23/Q` realization.

Test 0091 subsequently closes the exact-equation and ramification gates: a
bounded degree-28 recovery gives all 23 coefficients in one irreducible
number field and passes independent GAP/Sage exact verification. The
loop-lifting qualification in this note remains—the exact equation has strong
numerical monodromy evidence, not yet a formally certified exact-monodromy
calculation—and the result is still not an `M23/Q` realization.

## Reproduction

```sh
./scripts/run-8a-sage.sh --python \
  scripts/refine_8a_belyi_candidate.sage \
  data/derived/m23_8a_barth_wenz_domain2_certified_endpoint-path1.tsv \
  --precision-bits 4096 --maximum-iterations 20 \
  --output /tmp/m23_8a_high_precision_coefficients.tsv
./scripts/run-8a-sage.sh --python \
  scripts/compute_8a_cover_monodromy.sage \
  /tmp/m23_8a_high_precision_coefficients.tsv \
  --precision-bits 256 --steps-per-loop 512 \
  --output /tmp/m23_8a_cover_monodromy.tsv
python3 scripts/check_8a_high_precision_coefficients.py \
  data/derived/m23_8a_belyi_class1_high_precision_coefficients.tsv
python3 scripts/check_8a_cover_monodromy.py \
  /tmp/m23_8a_cover_monodromy.tsv
```

## Evidence

- `data/derived/m23_8a_belyi_class1_high_precision_coefficients.tsv`;
- `data/derived/m23_8a_belyi_class1_cover_monodromy.tsv`;
- `scripts/refine_8a_belyi_candidate.sage`;
- `scripts/compute_8a_cover_monodromy.sage`;
- `scripts/check_8a_high_precision_coefficients.py`;
- `scripts/check_8a_cover_monodromy.py`; and
- `data/derived/m23_8a_8a_2a_inner_classes.tsv`.
