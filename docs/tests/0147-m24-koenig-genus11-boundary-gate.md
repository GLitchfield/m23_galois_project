# Test 0147: König M24 genus-11 boundary and nonintegral gate

## Question

Do the three rational singular centers and the coordinate-boundary factors of
König's `(2A,2A,2B,8A)` plane model lift to `Q_2`-points on its normalization,
and which negative-valuation affine charts remain after a bounded exact audit?

## Exact singular-branch gates

The authenticated 633-term equation has three relevant rational singular
centers. Exact tangent and Newton data exclude a `Q_2`-rational branch above
each one.

- At `(t,x)=(0,0)`, the multiplicity is eight. The tangent cone is a product
  of two quartics. Their coefficient-valuation rows are
  `(9,8,5,4,0)` and `(9,8,5,5,0)`, so both lower Newton polygons have the
  single slope `-9/4`. A `Q_2` tangent direction would have integral
  valuation, hence neither quartic has a `Q_2` root.
- At `(0,-2)`, the multiplicity is two and the tangent equation is a nonzero
  scalar times `8t^2-x^2`. A rational tangent would make `8` a square, but
  `v_2(8)=3` is odd.
- At `(1/4,0)`, the tangent line is doubled. With weight two on `t-1/4` and
  weight one on `x`, the initial equation is
  `2^22(t-1/4)^2+2^8x^4`. Its second-order coefficient would satisfy
  `(128c)^2=-1`, impossible over `Q_2`.

These are statements about points on the normalization, not merely failures
of ordinary Hensel lifting on the singular plane model.

## Exact coordinate-boundary gates

The specializations and leading coefficient factor as follows:

```text
t = 0:       degrees 1^2, 1^8, 2^1, 6^2
x = 0:       degrees 1^2, 1^8, 10^1, 12^1
x = infinity: degrees 2^2, 4^4
```

The linear factors give only the three singular centers above. For every
nonlinear factor, its lower Newton polygon determines the only possible
integral root valuation. Exact enumeration of unit residues then becomes
empty:

| Boundary | Factor degree | Candidate valuation | Unit-root counts |
| --- | ---: | ---: | --- |
| `t=0` | 2 | 1 | `1,0` |
| `t=0` | 6 | 1 | `1,2,4,0` |
| `x=0` | 10 | -2 | `1,2,2,0` |
| `x=0` | 12 | -3 | `2,4,4,8,8,16,0` |
| `x=∞` | 2 | -2 | `0` |
| `x=∞` | 4 | -2 | `1,2,0` |

The coefficient of `t^32` is a nonzero constant, so the `t=∞`, finite-`x`
edge has no point.

## Bounded negative-valuation audit

For

```text
-40 <= v_2(t) <= -1
-40 <= v_2(x) <= 12
```

the audit computes the minimum coefficient/monomial valuation exactly.
Because the residue field has one nonzero unit, a unit chart can cancel
modulo two only when an even number of minimum terms occur. Exactly 100
valuation pairs pass this necessary tropical gate.

After eight recursively normalized unit-chart levels:

- 92 charts are dead;
- no simple Hensel root occurs;
- eight charts remain unresolved:

```text
(-6,0), (-2,0),
(-2,7), (-2,8), (-2,9), (-2,10), (-2,11), (-2,12).
```

The last six are progressively deep fixed-valuation neighborhoods of the
`(1/4,0)` boundary center. The exact branch calculation excludes a point
*above the center*, but this certificate does not derive an effective open
neighborhood bound that would remove those six finite charts. The genuinely
distinct unit charts `(-6,0)` and `(-2,0)` also remain.

This is substantial forward reduction, but not an all-chart proof that
`C(Q_2)` is empty. Valuations outside the declared window and the eight
surviving charts are explicitly unresolved.

## Provenance and replay

The compact certificate was generated at revision
`1250c325efa480d871f82115d522ffbe18d66e0d` with SageMath 10.9:

```sh
./scripts/run-8a-sage.sh --python \
  scripts/audit_m24_genus11_boundary.sage \
  /path/to/Polynomials_And_Approximation_Data.zip \
  --check-summary \
    data/derived/m24_koenig_genus11_boundary_gate.tsv

make check-m24-genus11-boundary
```

Certificate SHA-256:

```text
f6526b552e788ab87f04366985bacaf7ff22e540f5995435c4f1dd4e012f3a89
```

## Next gate

Replace raw translated-polynomial trees by canonical residue states for the
two unit charts `(-6,0)` and `(-2,0)`, and derive an effective exclusion
neighborhood for `(1/4,0)`. Then extend the tropical proof beyond the bounded
valuation window.
