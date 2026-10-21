# Test 0059: finite braid-action signatures of the small 8A components

## Question

Can a Galois-stable invariant of the degree-12 braid permutation action
distinguish either complex-conjugation survivor, component 3 or component 6,
from the other thirteen small `(8A)^4` components?

## Method and provenance

The test reruns the construction of all fourteen full Hurwitz components in
`scripts/gap/reproduce_8A_small_orbits.g`. For each sorted component it forms
the ordered permutation triple induced by the adjacent Hurwitz generators
`q2,q3,q4` on the twelve canonical inner classes.

GAP records:

- the Small Groups identifier of the generated permutation group;
- simultaneous-conjugacy classes of the ordered generator triples inside
  `Sym(12)`;
- conjugacy classes of the generated permutation subgroups inside `Sym(12)`;
- an explicit degree-12 transporter from the first ordered triple to each
  component's triple; and
- cycle structures for the generators and selected short products.

Every recorded transporter is immediately checked against all three
generators in GAP. The Python certificate generator independently checks the
same transporter equations against the 504 tuple-level edge destinations
from test 0058. Lean then proves the finite statement for all
`14 * 12 * 3` edge destinations in
`ordered_braid_actions_equivalent`.

Run:

```sh
make reproduce-8a-small-orbits
make check-lean
```

## Result

All fourteen components have:

- image group `SmallGroup(96,227)`;
- one simultaneous-conjugacy class of ordered generator triples;
- one conjugacy class of permutation subgroups in `Sym(12)`; and
- identical generator and selected short-word cycle profiles.

More strongly, the explicit transporters prove that the complete ordered
degree-12 actions are isomorphic, not merely that the sampled numerical
invariants agree. Components 3 and 6 are therefore indistinguishable from all
other components at this level.

## Verdict and boundary

Failed as a descent discriminator, but passed as a useful negative result.
No invariant determined solely by the finite ordered braid permutation triple
can isolate component 3 or component 6. This rules out the cheapest proposed
route from uniqueness of a topological action to definition over `Q`.

The calculation does not show that components 3 and 6 are Galois-conjugate,
nor that either is or is not defined over `Q`. Their distinction lies in the
embedding of the braid action into the `M23` Nielsen data or in genuinely
arithmetic information. Seguin's marked/unmarked comparison supplies no extra
escape here: for components whose monodromy is the full group, the marked and
connected-unmarked fields of definition agree. The next step should therefore
target that non-cyclotomic Galois action, not more invariants of the abstract
degree-12 action.
Test 0060 shows that Seguin's universal group-valued multiplicative lifting
invariant collapses as well.
Test 0061 carries out the next natural enrichment by attaching rational
pair-product boundary labels. Those labeled actions are isomorphic as well.

## Artifacts

- `data/derived/m23_8a_component_signatures.tsv`;
- `data/derived/m23_8a_component_witnesses.tsv`;
- `formal/M23Formal/Certificates/Test0058.lean`; and
- `scripts/gap/reproduce_8A_small_orbits.g`.
