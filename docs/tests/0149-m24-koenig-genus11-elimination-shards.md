# Test 0149: König M24 genus-11 elimination and resumable shards

## Questions

Can exact local elimination decide whether the bounded `(-6,0)` critical
cluster of Test 0148 is actually singular on the curve? Can every one of the
580 remaining `(-2,0)` boxes be advanced by deterministic, crash-resumable
shards?

## Exact `(-6,0)` elimination

Let `F(t,x)` be the integral `(-6,0)` chart of the authenticated 633-term
plane equation. Exact elimination first computes

```text
R(t) = resultant_x(F,F_x).
```

It has degree 1,216 and factorization

```text
1^64, 1^210, 2^4, 4^4, 34^1, 442^2.
```

The repeated discriminant part has degree 732 and factorization

```text
1^63, 1^209, 2^3, 4^3, 442^1.
```

Write `q(t)` for the irreducible degree-442 factor. Its values at the eight
distinct terminal `t` centers have 2-adic valuations

```text
23,24,23,25,23,24,23,29,
```

while `q'` is odd at every center. The centers agree modulo `2^23`, so
univariate Hensel lifting gives one exact root `t_0` in their common `Q_2`
disk.

The subresultant sequences for `(F,F_x)` and `(F,F_t)` are then reduced
modulo `q`. In both sequences the resultant is zero and the next term is a
linear polynomial in `x` with leading coefficient coprime to `q`. The two
linear terms are exactly proportional modulo `q`. Consequently they define
the same `x_0` over `Q[t]/(q)`, and

```text
F(t_0,x_0) = F_t(t_0,x_0) = F_x(t_0,x_0) = 0
```

holds algebraically, not merely to bounded 2-adic precision.

At this embedding, the negative Hessian determinant has square class

```text
valuation 8, odd unit 7 mod 8.
```

It is nonzero and nonsquare. Thus the point is an ordinary double point and
its two normalization branches are not `Q_2`-rational. This exactly excludes
the entire `(-6,0)` corridor.

The degree-442 factor and four very large linear-witness coefficients are
recorded by canonical SHA-256 digests. The witness coefficients themselves
have roughly 564,000-bit numerators, so committing them would add bulk without
improving replay: the authenticated archive replay recomputes them exactly.

## Resumable `(-2,0)` continuation

The 580 canonical boxes modulo `2^14` are assigned from the high four bits of
their two residue coordinates to four shards. The ownership counts are

```text
144,148,144,144.
```

Each base box is an atomic work unit. After it advances, the runner atomically
records all per-level dead, simple, unresolved, strong-Hensel, and terminal
residue data. Checkpoints bind the archive, model, base-frontier, shard layout,
runner-content, and unit-audit-content hashes. They retain their creation
revision but remain reusable across a commit when the executable source bytes
are unchanged.

All 580 work units completed. A second invocation reported

```text
0 new, 580 reused.
```

The four additional levels give:

| Modulus | Input boxes | Dead parents | Simple | Unresolved |
| ---: | ---: | ---: | ---: | ---: |
| `2^15` | 580 | 2 | 0 | 1,156 |
| `2^16` | 1,156 | 642 | 0 | 1,156 |
| `2^17` | 1,156 | 2 | 0 | 2,308 |
| `2^18` | 2,308 | 258 | 0 | 4,356 |

There is no simple or strong-Hensel point. The `(-2,0)` corridor therefore
remains unresolved, but it is now a complete resumable 4,356-box frontier
rather than an unsharded 580-box handoff.

## Provenance and replay

Both compact certificates were generated at revision
`55700f421c6933aab58fa0c9e404e80d6c549031` with SageMath 10.9:

```sh
./scripts/run-8a-sage.sh --python \
  scripts/audit_m24_genus11_local_elimination.sage \
  /path/to/Polynomials_And_Approximation_Data.zip \
  --check-summary \
    data/derived/m24_koenig_genus11_local_elimination.tsv

./scripts/run-8a-sage.sh --python \
  scripts/run_m24_genus11_minus2_shards.sage \
  /path/to/Polynomials_And_Approximation_Data.zip \
  --run-dir runs/m24-genus11-minus2-depth18-v3 \
  --shards 4 --prefix-bits 4 --extra-depth 4 \
  --check-summary \
    data/derived/m24_koenig_genus11_minus2_shards.tsv

make check-m24-genus11-local-elimination
make check-m24-genus11-minus2-shards
```

Certificate SHA-256 values:

```text
66692bb75da5db6bf093e3d80634da8abf3a8d87da9d1938360d5fbe658ccb28
cf04ea940c7edcbbb5ad860190d3547fd755744ae836c43f532e5c7a4aed4b1a
```

The operational shard checkpoints and external OPUS archive are not
committed.

## Next gate

Cluster the 4,356 terminal `(-2,0)` boxes by compatible critical-point
approximations and apply the same exact resultant/subresultant method to any
stable clusters. In parallel, extend the tropical valuation window beyond
the bounded range of Test 0147 before claiming a complete `Q_2` obstruction.
