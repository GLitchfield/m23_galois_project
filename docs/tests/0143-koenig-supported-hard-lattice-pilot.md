# Test 0143: König supported hard-column lattice pilot

## Question

Do larger, non-nested q-ary lattices targeted at the least stable columns of
the certified rank-seven supported free-module chart recover a short rational
basis?

## Result

The matched planted rank-seven gate passes, but the real search has no
candidate that recurs in two independent blocks and therefore no credible
short basis.

At effective digits 8, 9, and 10, the `7 x 7559` chart columns split into:

```text
fully stable (7/7 entries stable)       2016
partially stable (1/7 entries stable)    106
fully unstable (0/7 entries stable)     5437
```

Of the 5,437 fully unstable columns, 3,800 also have all seven entries change
from effective digit 9 to digit 10. The pilot constructs 12 non-nested blocks
of sizes 24, 32, and 40 from this hard stratum and applies five leading
weights, for 60 deterministic LLL configurations.

These configurations yield 2,338 distinct leading vectors. None appears in
two independent blocks. Scoring every proposal on all 7,566 module
coordinates gives a best digit-9-to-10 stability of only 2,410, far below the
predeclared 6,810-coordinate credibility threshold:

```text
leading =
  1950940970,4571161331,-11659372082,-4302614530,
  -6459279085,6276338134,-15329882625
support_blocks = 1
support_configurations = 1
stable_previous = 2410 / 7566
stable_two_back = 2046 / 7566
within_symmetric_bound = 2016 / 7566
maximum_absolute_coefficient = 3065362313767
```

The maximum coefficient is again essentially half of
`19^10 = 6,131,066,257,801`, as expected for a random centered modular lift.
More pointedly, the 2,016 entries within the symmetric rational-reconstruction
bound exactly equal the 2,016-column universally stable baseline. The hard
coordinates add no reconstruction signal.

This is stronger evidence than Test 0142's small-block result: larger blocks
selected specifically for instability produce no recurrence at all. Together
the two bounded experiments close the present short-vector/LLL route. They do
not prove that the rational module has no short basis or rule out a different
global reconstruction method.

## Method

For each chart column, the producer counts how many of its seven centered
entries agree across effective digits 8, 9, and 10. It retains the 5,437
columns with zero stable entries. Blocks use sizes `24,32,40`, four base
offsets `0,509,1901,3701`, coprime steps `37,101,211,503`, and an
offset stride of 787 so that the blocks change with size and none is a strict
subset of another.

Each block forms the q-ary row lattice

```text
[ w I_7   C_block ]
[   0     19^10 I ],
```

for `w` in `1,4,16,64,256`. Every reduced leading vector is scored on the
complete chart with exact Python-integer modular products centered at
effective digits 8, 9, and 10. Recurrence requires support from at least two
independent blocks; credibility additionally requires 6,810 stable
coordinates.

The synthetic gate exposes 768 columns from a rank-seven module after a
non-unimodular integral basis change. The same hard-column selector leaves 107
fully unstable columns, and the bounded search recovers 26 recurrent short
vectors spanning rank seven; three of the seven original planted basis rows
occur explicitly.

The independent Python checker reloads the certified chart, recomputes its
instability census and all reported full-vector metrics without `uint64`
multiplication, verifies the configuration support, ordering, thresholds, and
input hashes, and confirms zero recurrence. A separate producer replay
regenerates the deterministic summary byte for byte. The official SageMath
10.9 pilot took 52.15 seconds with maximum RSS 241,352 KiB.

## Evidence

Production code revision:
`e48c6f9cd290754fc16e6d7e2215e7afa13d1223`.

```text
8e02c1b72852e7a257b42de8c4393f844d6ef1129b9d5e55f72921e6530386bb
  data/derived/m23_koenig_a_relation_supported_beta77_hard_lattice_pilot.tsv
```

Replay:

```sh
make check-koenig-relation-supported-hard-lattice
```

## Next gate

Test 0144 moves away from same-prime lattice variants. It finds many smooth
points outside the reductions of the five reported boundary points on
König's plane model at 11, 13, and 17, but the first bounded normalized-cover
solve times out and the released numerical fiber does not pass an exact
multi-chart reconstruction gate. The complete degeneration divisor remains
unknown. A high-order second-prime lift and multi-prime CRT reconstruction
are therefore not yet authorized.
