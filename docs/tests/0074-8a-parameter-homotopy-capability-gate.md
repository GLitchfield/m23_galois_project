# Test 0074: parameter-homotopy capability gate for the 8A Belyi target

## Question

Does the locked numerical environment support the parameter paths and
polynomial-system monodromy proposed after test 0073, and does the repository
already contain a solved Belyi system that is genuinely related to the target?

## Two separate gates

A software API and a mathematically meaningful deformation are different
requirements.

The **capability gate** asks whether the pinned
HomotopyContinuation.jl version can:

1. track a solution through several parameter waypoints;
2. recover the two a priori known solutions of a quadratic parameter fibre
   when that expected count is supplied to its monodromy solver; and
3. transport the recovered solutions to a new parameter value.

The **related-start gate** requires more. A source point must be a known
nondegenerate solution of a polynomial family whose relevant fibres have an
explicit Belyi or Hurwitz-space interpretation connecting source and target.
Merely replacing the target equations `F(v)=0` by `F(v)=c` makes a valid
polynomial family, but not a family of related Belyi maps: its intermediate
fibres generally do not impose the target ramification identity.

The `monodromy_solve` API below is likewise a method for finding solutions of
a polynomial system by continuation around parameter loops. It is not the
permutation monodromy of a Belyi cover. Any candidate map still needs the
separate cover-monodromy verification identified by test 0069 and the roadmap.

## Method

The deterministic regression uses the one-variable family

```text
x^2 - p = 0.
```

Starting at `(x,p)=(1,1)`, it tracks through the parameter waypoints `1+i` and
`2`. A separate run starts from one solution over `p=1`, asks
`monodromy_solve` for both solutions with certified duplicate checking, and
then transports both to `p=2`. Threading is disabled and the seeds are fixed.

The environment is Julia 1.12.6 and HomotopyContinuation.jl 2.21.0, locked in
`julia/8a_belyi/Manifest.toml` at package tree
`48ee7ee28e09b00d5237327a8ae124caf590125f`. The regression was committed at
revision `68b41f23e6ee5a974cf7db364ebf9913979d8ae1` before this note was written.

The documented candidate inventory is:

| candidate | project evidence | why it does not close the gate |
| --- | --- | --- |
| normalized 8A equations | test 0068 and `m23_8a_belyi_normalized_system.m` | target system, no solved nondegenerate point |
| circle-packing points | tests 0071--0073 and their TSVs | approximate seeds or artificial residual-shift starts; accepted Belyi endpoint absent |
| exact verifier fixtures | test 0069 | deliberately small maps for checking the verifier, not this passport |
| Elkies' degree-23 `M23` polynomial | tests 0067 and the literature audit cite the publication | different passport; coefficients and an adapter are not committed |

This inventory can be checked against tracked Belyi/Hurwitz filenames and the
documented mentions of solved or known solutions with:

```sh
git ls-files | rg -i 'elkies|belyi|hurwitz'
rg -n -i 'Elkies|known solution|solved.*Belyi|Belyi.*solution' \
  --glob '!papers/**' --glob '!runs/**' --glob '!trash/**' .
```

Those searches are an auditable documentation gate, not a proof that an
unmentioned compatible object cannot exist elsewhere in the repository.

## Result

The capability gate passes on the fixture:

- both waypoint segments return `success`;
- their path residuals pass the committed `1e-12` gate;
- the final equation residual at `p=2` passes the committed `1e-12` gate;
- polynomial-system monodromy recovers two solutions over `p=1` and certifies
  them distinct after the known target count `2` is supplied; and
- transport recovers two solutions over `p=2`, both passing the committed
  `1e-12` equation-residual gate.

The two testsets contain eleven passing assertions. No performance or
completeness inference for a fibre with unknown cardinality follows from this
fixture. In particular, API availability says nothing about tractability for
the degree-23 target.

The related-start gate remains open: no committed, solved, nondegenerate source
fibre with the required mathematical connection is identified by the
documented project inputs above. This is not a proof of absence elsewhere in
the repository or literature, nor a proof that no such deformation can be
designed.

## Consequence

Do not describe another `F(v)=c` waypoint experiment as continuation from a
related Belyi map. Such a run could still be a bounded test of whether bending
the artificial residual-shift path avoids the particular infinity components
seen in test 0073, but its claim must remain that narrow.

The next high-value routes are therefore:

1. obtain a specialized Magma `BelyiMap` feasibility result for one of the 28
   exact triples;
2. construct or source a solved compatible Belyi/Hurwitz fibre and document
   the mathematical parameter family before launching a staged homotopy; or
3. if external access is delayed, first design a reproducible diagnostic for
   the infinity components reached in test 0073; only a diagnostic that gives
   a concrete reason to bend the path should motivate one pre-registered
   residual-waypoint path with fixed wall-clock, step, precision, and
   coordinate-growth limits.

This gate does not authorize a target-sized `monodromy_solve` enumeration: the
target fibre has no independently known solution count or completeness
criterion, and the cost is unknown. Any residual-waypoint run must make no
claim that its intermediate fibres are Belyi maps.

Passing any numerical route produces a candidate, not a theorem. Exact
ramification and nondegeneracy checks remain mandatory. A claimed coefficient
field additionally needs a CAS irreducibility certificate for its defining
polynomial and a check that every recognized coefficient lies in that field;
at the time of this gate's initial review, test 0069 did not prove
irreducibility. Its candidate-intake upgrade now invokes GAP for that proof and
fails closed on a missing verdict. Cover monodromy remains a separate mandatory
certificate.

## Adversarial review

A local Fable/Codex evidence-packet review was used as a drafting check, not as
mathematical evidence. Both reviewers accepted the central trust boundaries
but identified five correctable problems: uncommitted sub-`5e-16` and timing
figures, overbroad `all solutions` wording, ambiguous language suggesting that
Elkies' coefficients were stored locally, an insufficiently reproducible
related-start inventory, and an underspecified coefficient-field check. The
published note removes the uncommitted measurements, limits completeness to
the known quadratic fixture, records the inventory and search commands, says
that Elkies is cited rather than imported, and requires a separate CAS
irreducibility certificate.

The reviewers also agreed that this fixture does not justify target-sized
polynomial-system monodromy. That conclusion was checked against the test code
and retained as an explicit gate above; model agreement itself is not a
certificate.

## Reproduction

```sh
make check-8a-continuation
```

The complete repository regression also passed at the committed capability
revision:

```sh
make test
```

## Evidence

- `julia/8a_belyi/test_continuation.jl`;
- `julia/8a_belyi/Project.toml`;
- `julia/8a_belyi/Manifest.toml`;
- `docs/tests/0067-8a-belyi-public-data-audit.md`;
- `docs/tests/0068-8a-normalized-belyi-equations.md`;
- `docs/tests/0069-exact-belyi-candidate-verifier.md`;
- `docs/tests/0071-8a-dessin-seeded-numerical-pilot.md`;
- `docs/tests/0072-8a-projective-continuation-pilot.md`; and
- `docs/tests/0073-8a-five-factor-saturated-continuation.md`.
