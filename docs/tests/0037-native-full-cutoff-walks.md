# Test 0037: native full-cutoff 4A and 5A walks

## Question

Does the native coordinate backend retain exact GAP orbit membership at the
real 4A and 5A proof cutoffs, including 5A crossings through the previously
unsupported identity-product macroblock, and is the measured speedup large
enough to justify production-ledger integration?

## Inputs and provenance

- implementation: the commit containing this note;
- 4A pair checkpoint SHA-256
  `add26b95401d74fbaf29167782667080275d848b8cddabceecef40c2051c75c4`;
- 5A pair checkpoint SHA-256
  `1d6653fedb4327ed4594a1ca55cad03b82fbcae5a45817dbadeede05902468ea`;
- 5A global coordinate checkpoint SHA-256
  `08b2b789db8e2fc9e00c917ac4f28a750965fe9390e8cae7ae4a793ce9b4cedc`;
- GAP 4.12.1 and g++ 13.3.0 on the 24-thread, 32 GiB WSL2 workstation;
- no GPU code or GPU timing.

The committed TSV fixtures are complete ordered vertex lists, not aggregate
checksums. The long 5A regression regenerates both the GAP oracle and the
native coordinate checkpoint when operational copies are absent:

```bash
make check-native-5a-walk
```

The timed native invocation is:

```bash
scripts/benchmark-native-bounded-walk.sh \
  runs/5a-coordinate-tables-cbb8ab9.bin 71532995 1 5 30400 3
```

## Identity coordinate

The identity-product macroblock has one symbolic block but 45,344 singleton
pair-twist vertices for 5A. Materializing an M23-sized transporter table would
undo the global compression. Instead, after fixing the first tuple entry, the
third entry determines one existing target-centralizer pair orbit. Native IDs
order the corresponding `(product_class, pair_id)` keys lexicographically.
The already exported 680,064-row target-pair lookup therefore locates identity
vertices without another global table.

GAP independently translates its arbitrary identity double-coset numbering to
the same stable keys. The known 5A component crosses the identity block at 28
distinct vertices, so the comparison exercises this path rather than merely
constructing it.

## Exact results

| target | cutoff | status | checked vertices | discovered vertices | weighted classes |
| --- | ---: | --- | ---: | ---: | ---: |
| 4A | 2,500 | overflow | 14 | 261 | 2,504 |
| 5A | 30,400 | closed | 5,498 | 5,498 | 30,400 |

For both targets, GAP and C++ agree on every ordered
`(macroblock, native_twist_id, weight)` row and on terminal status and counts.
The full 5A comparison reproduces the known component rather than merely
matching its size.

## Timing

| target | implementation | wall time | maximum RSS |
| --- | --- | ---: | ---: |
| 4A | GAP fixture oracle | 12.76 s | 260,376 KiB |
| 4A | native process | 0.36--0.37 s | 115,312--116,064 KiB |
| 5A | GAP fixture oracle | 147.88 s | 796,148 KiB |
| 5A | native process, three walks | 3.54 s | 380,752 KiB |

The 5A native process spent 288 ms loading the 131 MB checkpoint, 770 ms
building its global hash indexes, 1.768 s in the first cold walk, and 198--215
ms in each repeated walk after lazy block tables were cached. The differential
oracle comparison is about 42 times faster end to end. Against the earlier
91-second GAP production traversal of this component, the native process is
still about 26 times faster.

These are exact component timings, not a 26--42x exhaustive-search forecast.
The benchmark omits native block scheduling, generation-mask application,
SQLite ownership/link lookup, certificate commits, and independent replay.
Because quotient walking was 84--89 percent of measured GAP scanner time, a
25x acceleration of only that phase would imply an Amdahl-limited roughly
5--7x end-to-end improvement. That makes a one-to-two-week native 5A target
plausible enough to pursue, while the measured five-to-seven-week GAP plan
remains the baseline until a sustained native ledger exists.

## Verdict

Passed the full 4A cutoff, complete known 5A component, stable identity-block
coordinate, deterministic repeat, and bounded-memory gates. The next milestone
is a small fresh native ledger combining block refinement, 14-bit generation
masks, external ownership lookup, and GAP replay by orbit membership.
