# Test 0142: König supported free-module lattice pilot

## Question

Can deterministic low-dimensional q-ary lattices recover a short rational
basis of the certified rank-seven supported free module, even when the
canonical 19-adic chart is obscured by a rational basis change?

## Result

The planted rank-seven gate passes, but the bounded search finds no credible
short basis in the real module.

The planted gate starts with seven small integral vectors, applies a
non-unimodular integral basis matrix of determinant 510,510, and exposes only
the resulting canonical modular chart at `19^10`. The same search recovers 32
recurrent short vectors of leading rank seven; four of the original planted
basis rows occur explicitly.

For the real `7 x 7559` free chart, 80 deterministic LLL configurations
produce 1,307 distinct leading vectors. Of these, 127 recur in at least two
configurations and are scored on all 7,566 module coordinates at effective
digits 8, 9, and 10.

No recurrent candidate reaches the credibility gate of 6,810 coordinates
stable from effective digit 9 to digit 10. The best candidate stabilizes only
2,377:

```text
leading = 4033851,1334318,10881701,68275,304197,-3746566,461405
support = 2
stable_previous = 2377 / 7566
stable_two_back = 2045 / 7566
within_symmetric_bound = 2020 / 7566
maximum_absolute_coefficient = 3064059168474
```

The maximum coefficient is essentially half the modulus
`19^10 = 6,131,066,257,801`, characteristic of a random centered lift rather
than a short rational vector. The other leading candidates have the same
profile. Their leading rank is therefore irrelevant: none passes the
whole-vector cross-precision gate, and the credible rank is zero.

This closes only the tested small-block LLL search. It does not prove that the
rational module has no short basis, nor does it rule out vectors exposed by
larger or deliberately selected coordinate blocks.

## Method

For each subset of chart columns, the Sage producer constructs the q-ary row
lattice

```text
[ w I_7   C_subset ]
[   0     19^10 I  ],
```

where `w` is one of `1,4,16,64,256`. A reduced vector whose first seven
coordinates are divisible by `w` proposes a linear combination of the seven
canonical chart rows.

The bounded grid uses subset sizes `8,12,16,20`, offsets
`0,101,1009,3001`, and coprime step 997. Candidates must recur in at least two
configurations. Every recurrent candidate is then multiplied against the
complete chart with exact Python-integer modular products and centered at
effective digits 8, 9, and 10.

The independent Python checker reloads the certified chart, recomputes every
reported full vector and stability metric without `uint64` multiplication,
checks ordering and thresholds, and verifies the input hashes. The official
SageMath 10.9 pilot took 3.52 seconds with maximum RSS 237,184 KiB.

## Evidence

Production code revision:
`dfe414d26de251a9002ee76aae16c7c3d98c7401`.

```text
07a1c4c2ac8ca5b8079af191026555a77c4bcefc793097604c56133e97b5505f
  data/derived/m23_koenig_a_relation_supported_beta77_free_lattice_pilot.tsv
```

Replay:

```sh
make check-koenig-relation-supported-free-lattice
```

## Next gate

Test 0143 runs the prescribed hard-column-stratified extension. Its larger,
non-nested blocks again pass a matched planted `GL_7(Q)` gate, but none of
2,338 real candidates recurs in two independent blocks. This stronger
negative closes the bounded short-vector route and moves the next gate to a
second-prime feasibility audit.
