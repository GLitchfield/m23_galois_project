# Test 0026: mature-ledger throughput

## Question

Does the apparent 4A mathematical runtime actually come from quotient-group
work, or does exact progress monitoring dominate once the SQLite ledger has
millions of rows? Can that overhead be removed without changing any replayed
certificate or block result?

## Environment

- GAP 4.12.1
- Python 3 standard-library SQLite
- verified 425,000-block base, SHA-256
  `c0c0e0b065370572132e5a546695dc200587ca6c6e909322f75253ea8e56e7e9`
- proof limit 2,500; coverage-walk limit 25,000; frontier scheduling
- 32 GiB RAM and 8 GiB swap

## Method

An identical one-worker 100-block extension was run three times from a fresh
copy of the verified base:

1. exact whole-ledger statistics after every block;
2. statistics every 100 blocks;
3. statistics every 100 blocks, completed frontier rows removed from the
   pending queue, and `certificates(seed_ordinal)` indexed.

GAP phase timers recorded claim, refinement, generation/lookup, quotient walk,
commit, and finish time. `/usr/bin/time -v` recorded end-to-end time and peak
RSS. The final optimized 100-block delta was independently replayed by both the
certificate and block verifiers.

The scaling check then ran 1,000 blocks with four workers and 10,000 blocks
with eight workers. Both runs began from the same immutable 425,000-block base;
the 1,000-block result passed exact parallel replay before the larger run.

## Result

| Configuration | Blocks | Workers | Wall seconds | Blocks/second |
| --- | ---: | ---: | ---: | ---: |
| Per-block full statistics | 100 | 1 | 205.15 | 0.487 |
| Statistics every 100 blocks | 100 | 1 | 44.25 | 2.260 |
| Pending queue plus seed index | 100 | 1 | 14.72 | 6.793 |
| Optimized multiworker | 1,000 | 4 | 28.75 | 34.783 |
| Optimized production sample | 10,000 | 8 | 181.19 | 55.191 |

The baseline GAP mathematical phases totaled only 4.75 CPU-seconds. Full
statistics required a two-million-row pending-frontier join after every block;
the old frontier claim also scanned past completed history, and finishing a
block scanned the unindexed certificate table by seed. These were persistence
and observability costs, not braid computation.

The 100-block optimized delta passed exact certificate replay, block
rematerialization, base preservation, and deterministic ownership. It contains
59 linked certificates and 203 new vertices. The 1,000-block delta also passed
all gates, with 667 linked certificates and 2,248 new vertices.

The 10,000-block candidate contains 435,000 total blocks, 464,524 certificates,
and 3,075,650 vertices. Its delta has 8,076 linked certificates and 27,425
vertices. Promotion remains conditional on its independent replay and audit.

Peak RSS for an individual scan worker remained below 400 MiB. The optimized
scan therefore changes the current 4A projection from roughly nine days to
about 38 hours of scanning if the measured 55.2 blocks/second persists. Replay
and recovery margin must still be added.

## Native-code implication

After removing the monitoring overhead, quotient walking accounts for about
84--89 percent of GAP phase time and refinement about 9--13 percent. The
checked C++ kernel now includes a real generating `(4A,4A,2A,2A)` fixture, but
the remaining hot boundary includes GAP coordinate lookup and relative
double-coset data around the native braid moves. Calling only the permutation
kernel across a process boundary would not accelerate that lookup. A future
native integration must therefore include a versioned coordinate checkpoint,
not merely the existing move formulas.

## Artifacts

The operational ledgers and replay reports are under:

- `runs/4a-native-profile-100*`
- `runs/4a-optimized-benchmark-1000`
- `runs/4a-optimized-benchmark-10000`

The permanent regression coverage is in:

- `scripts/test_quotient_ledger.py`
- `data/reference/native_kernel_fixture.tsv`
- `tests/native/test_m23_kernel.cpp`
