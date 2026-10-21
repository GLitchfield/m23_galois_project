# Test 0071: dessin-seeded numerical pilot for the 8A Belyi target

## Question

Can a deterministic circle-packing approximation to the first certified
`(8A,8A,2A)` dessin seed a nondegenerate numerical solution of the normalized
degree-23 Belyi equations?

## Method

The pilot reads class 1 directly from the complete test-0064 certificate.  It
constructs the black, white, and face cycles, retains parallel edges and digon
faces, and barycentrically subdivides the flag triangulation.  The base sphere
has 140 vertices, 414 edges, and 276 triangles.  Each optional refinement sends
`(V,E,F)` to `(V+E+F, 6E, 6F)`.

For a fixed outer triangle, a sparse Newton solve chooses circle radii whose
interior angle sums are `2*pi`.  Two-circle intersections then develop all
centres across the dual graph.  The branch-cycle vertices provide approximate
roots for the canonical test-0068 identity

```text
P + F - Q = 0.
```

The final solve uses all 23 coefficient equations.  A second homotopy augments
them with inverse variables for five saturation factors: nonzero `alpha`, the
three fibre Vandermonde products, and the `P`--`F` resultant.  This is essential:
a small raw residual can otherwise be obtained by shrinking the map or merging
roots.

## Result

All three circle packings close reliably.  At two refinements the mesh has
4,970 vertices and 9,936 triangles; its maximum tangency error is
`3.64e-11`.  Refinement improves the unrestricted coefficient residual:

| refinements | relative residual | `abs(alpha)` | `Q` Vandermonde | saturated path |
|---:|---:|---:|---:|---|
| 0 | `3.82e-5` | `3.38` | `5.93e17` | step underflow before `t=1` |
| 1 | `1.68e-6` | `1.70e-3` | `1.17e-3` | step underflow before `t=1` |
| 2 | `2.56e-7` | `1.87e-2` | `5.12e-77` | step underflow before `t=1` |

The finest raw Newton result is therefore decisively degenerate: an entire
fibre is collapsing.  It also misses the `1e-10` residual gate.  The
saturation-aware homotopy rejects every mesh level rather than reporting this
boundary point as a map.

This is a negative **solver** result only.  It is not evidence that the Belyi
map does not exist; the permutation triple guarantees the corresponding
complex cover by the classical Riemann existence/branch-cycle theorem, which
is external established mathematics and not currently Lean-formalized. It
says that circle centres from up to two barycentric
refinements, followed by this coefficient-space Newton/homotopy method, do not
yet supply an acceptable numerical representative.

## Reproduction

Install the isolated optional dependencies and run:

```sh
python3 -m pip install -r requirements-8a-belyi-pilot.txt
python3 scripts/pilot_8a_belyi_circle_pack.py \
  --refinements 2 --newton-iterations 1500
```

The recorded run used Python 3.12.3, NumPy 2.4.3, SciPy 1.16.0, code revision
`65f64f147c448054a44321bd5f8317017372f450`, and the input hash stored in the
TSV.  The calculation takes about 16 seconds on the project workstation.  The
large mesh and iterates are intentionally not committed.

## Consequence

Do not attempt coefficient recognition or exact verification on these
iterates.  The next high-value route remains the public Magma Belyi package (or
help from its authors), which implements the established specialized solver.
A local continuation effort should first improve the numerical formulation:
use genuine dessin refinement coordinates, multiple outer-face normalizations,
and a robust projective/saturation-aware path tracker.  Only a nondegenerate
candidate should proceed to test 0069 and independent monodromy certification.

## Evidence

- `data/derived/m23_8a_belyi_circle_packing_pilot.tsv`;
- `scripts/pilot_8a_belyi_numeric.py`;
- `scripts/pilot_8a_belyi_circle_pack.py`; and
- `requirements-8a-belyi-pilot.txt`.
