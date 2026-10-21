# Test 0104: König component-to-plane map gate

## Question

Does the authenticated 980-cover archive certify that König's plane equation
is the characteristic-zero genus-43 `C2`-symmetrized Hurwitz component, and
what exact artifact would close the remaining gap?

## Primary-source coordinate map

König's dissertation, Chapter 5.3, pages 73--76, defines a normalized
universal family

```text
t - 1/4       = C f1(X)^3 f2(X) / (g1(X)^5 g2(X)),
t - 1/2 - λ   = C f3(X)^2 f4(X) / (g1(X)^5 g2(X)),
t - 1/2 + λ   = C f5(X)^2 f6(X) / (g1(X)^5 g2(X)).
```

The monic degrees are `(6,5,8,7,8,7,3,3)`, the `X^2` coefficients of
`g1,g2` are normalized to `1/3,-1/2`, and the plane coordinates are

- `alpha`: the `X^4` coefficient of `f2`; and
- `beta`: the `X^5` coefficient of `f1`.

The dissertation says that the archived polynomial is an algebraic
dependency between these functions. Its proof of genus 43 then uses
numerically determined ramification, so the source itself does not supply the
exact comparison sought here.

## Complete-fiber numerical audit

Implementation revision:
`796b3d525c03f6b886e9935b67065dd7d8fcbec0`.

Run:

```sh
make check-koenig-component-map KOENIG_ARCHIVE=/path/to/archive.zip
```

`scripts/audit_koenig_component_map.sage` authenticates the official archive
and parses every one of its 980 coefficient vectors at 700-bit precision.
Each vector has exactly 46 entries, matching all unfixed coefficients in the
normalized model. The recovered archive order is

```text
f5, f6, f1, f2, f3, f4, g1-unfixed, g2-unfixed, C.
```

Consequently `alpha,beta` are entries 22 and 16 in one-based indexing. For
every vector, the verifier reconstructs the three degree-23 numerators and
checks the two model identities, then evaluates the exact archived
bidegree-`(97,98)` polynomial at `(alpha,beta)`.

The complete-fiber maxima and separation are:

| Check | Result |
| --- | ---: |
| vectors | 980 |
| largest relative model-identity residual | `< 5.35e-199` |
| largest relative plane-relation residual | `< 1.87e-161` |
| minimum pairwise `(alpha,beta)` separation | `> 0.0285` |

Thus every archived cover lands numerically on the plane curve, and the 980
pairs separate the complete fiber. This is strong evidence that the
coefficient map is generically degree one. It is not an exact algebraic
certificate: the archive supplies decimal approximations without certified
error balls, and even certified balls would not turn near-zero evaluations
into a rational-function identity.

## Exact theorem chain

Let `C` be the independently braid-computed `C2`-symmetrized Hurwitz
component, and let `D` be the normalization of the absolutely irreducible
archived plane curve.

The repository already proves:

1. `g(C)=43`;
2. the plane polynomial is absolutely irreducible over `Q`; and
3. exact reductions at 13 and 17 have normalization genus 43, hence
   `g(D)>=43` in characteristic zero.

It remains to prove:

1. `h(alpha,beta)=0` as an exact identity in `Q(C)`; and
2. at least one of `alpha,beta` is nonconstant on `C`.

Those facts induce a dominant map `C -> D`. Riemann--Hurwitz gives
`g(D)<=g(C)=43`, so the modular lower bound forces `g(D)=43`. Applying
Riemann--Hurwitz again,

```text
84 = degree(C -> D) * 84 + ramification_degree,
```

forces degree one and zero ramification. Degree one is therefore a
consequence, not a separate premise.

## Bounded alternatives

An exact `Q`-resultant probe for `Res_x(h,dh/dx)` was given a 1,800-second
hard bound and did not return. Together with the earlier bounded
normalization calls, this makes a monolithic characteristic-zero
discriminant or delta calculation the least practical current route.

A full reciprocal Fable/Codex review was run read-only at revision
`796b3d5`, with packet SHA-256
`eaa2e8f7e9a451569cc1dcb426ce9dce38bf0314e800cd7b550b35966e26d2c6`,
models `claude-fable-5` and `gpt-5.4`, and one critique round. Both reviewers
identified the same missing identities and rejected the numerical audit as a
closing proof. The review is advisory, not evidence.

## Stopping gate

The preferred gate-closing artifact is an exact tautological-family
certificate over

```text
K = Frac(Q[alpha,beta] / (h)).
```

It must:

1. give exact coefficient expressions for the normalized factors
   `f1,...,f6,g1,g2,C` and the moving branch-pair parameter, allowing the
   quadratic extension that labels the two `2A` branches;
2. verify the three polynomial identities of the universal family exactly;
3. make `alpha,beta` the stated coefficients tautologically, proving the
   function-field identity and nonconstancy;
4. certify one nondegenerate `M23` specialization and an upper-bound
   certificate proving that the generic group is contained in `M23` (the
   specialization alone proves only `M23 <= G` and does not exclude `A23`),
   then use the unique 980-class braid component to identify the family with
   `C`; and
5. record the archive hash, code revision, Sage/CAS versions, and exact
   replay command.

Until that artifact or a direct characteristic-zero delta certificate exists,
the component-to-plane identification and genus equality remain very strongly
supported but not independently proved.
