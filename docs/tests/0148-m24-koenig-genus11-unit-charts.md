# Test 0148: König M24 genus-11 deep unit charts

## Question

Can the two distinct unit corridors left by Test 0147,
`(v_2(t),v_2(x))=(-6,0)` and `(-2,0)`, be resolved or materially reduced
without duplicating translated full-polynomial states?

## Canonical residue states

The audit identifies a chart by its two absolute unit residues and modulus.
It still uses the exact normalized child polynomial to classify the next four
bits, but it independently reconstructs every terminal chart directly from
the authenticated global equation. This checks that incremental content
division has not changed or duplicated a residue box.

For `(-6,0)`, the unresolved counts are

```text
2,4,8,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16
```

Thus exactly 16 boxes persist through modulus `2^26`. None is an ordinary
simple Hensel box, and none of their integer centers satisfies the strong
one-variable Hensel inequality after fixing the other coordinate.

All 16 terminal centers have Hessian-discriminant square class

```text
valuation 8, odd unit 7 mod 8
```

and a 200-bit Newton probe sends all 16 centers to one critical-point cluster.
At that precision the equation and both derivatives vanish through at least
162 bits, while the tangent discriminant remains nonsquare.

This is compelling evidence that the boxes converge to one ordinary double
point with no `Q_2`-rational normalization branch. It is deliberately not
recorded as an exact exclusion: the bounded characteristic-zero Gröbner
attempt for the global singular ideal did not finish, so the audit has not
proved that the limiting critical point lies exactly on the curve.

For `(-2,0)`, the canonical counts through modulus `2^14` are

```text
4,6,10,16,24,28,44,84,84,164,292,324,580.
```

No simple or strong-Hensel point appears. A depth-11 residue `(897,335)`
initially produced an apparent square critical discriminant under an
under-precise Newton experiment. Exact continuation falsifies that candidate:
it has no descendant among the terminal boxes modulo `2^14`.

## Conclusion

The `(-6,0)` corridor is reduced to one bounded nonsquare critical cluster,
and a concrete false-positive mode in `(-2,0)` is removed. The local-solubility
question remains open: `(-6,0)` needs an exact singular-ideal certificate, and
580 `(-2,0)` boxes remain.

## Provenance and replay

The certificate was generated at revision
`5c6dae3f27038e92f28902c4dcac849e83299a57` with SageMath 10.9:

```sh
./scripts/run-8a-sage.sh --python \
  scripts/audit_m24_genus11_unit_charts.sage \
  /path/to/Polynomials_And_Approximation_Data.zip \
  --check-summary \
    data/derived/m24_koenig_genus11_unit_chart_gate.tsv

make check-m24-genus11-unit-charts
```

Certificate SHA-256:

```text
0a7eb9b4936a86f0e907644c0058b2080545d2c32ddc42354b5d2d80ff6ea6e5
```

## Next gate

Compute the `(-6,0)` singular ideal locally, preferably with modular
elimination plus rational reconstruction instead of a global Gröbner basis.
For `(-2,0)`, shard the 580 terminal boxes by residue prefix and advance them
resumably, recording extinct, simple, strong-Hensel, and critical-cluster
outcomes independently.
