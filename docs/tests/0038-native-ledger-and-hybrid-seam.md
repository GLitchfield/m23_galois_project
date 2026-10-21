# Test 0038: native ledger and additive hybrid seam

## Question

Can the exact native 5A coordinate backend enumerate a fresh block, apply the
certified generation masks, stop a bounded walk at externally owned vertices,
emit a deterministic certificate transcript, and import that transcript into
an integrity-checked SQLite ledger? Can future CPU/GPU work be partitioned and
measured as additive system throughput rather than as GPU replacement of CPU?

## Inputs and provenance

- implementation: the commit containing this note;
- 5A pair checkpoint SHA-256
  `1d6653fedb4327ed4594a1ca55cad03b82fbcae5a45817dbadeede05902468ea`;
- coordinate checkpoint SHA-256
  `08b2b789db8e2fc9e00c917ac4f28a750965fe9390e8cae7ae4a793ce9b4cedc`;
- generation-mask checkpoint SHA-256
  `0e39a410106cb5f18dc6f8fca24b702109e4614a35345a3200e2edd519b1fe7b`;
- source block `71532995`, proof/walk cutoff `30400`;
- GAP 4.12.1 and g++ 13.3.0 on the 24-thread, 32 GiB WSL2 host;
- CUDA is measured separately in test 0039.

The operational transcript and database remain under `runs/` and are not
committed. They can be regenerated with:

```bash
scripts/generate-5a-generation-masks.sh runs/5a-generation-masks.bin
scripts/run-native-ledger-batch.sh \
  runs/5a-coordinate-tables-cbb8ab9.bin \
  runs/5a-generation-masks.bin 71532995 1 30400 30400 \
  runs/5a-native-ledger-1block.tsv
python3 scripts/import_native_ledger_batch.py \
  runs/5a-native-ledger-1block.tsv \
  runs/5a-native-ledger-1block.sqlite3
python3 scripts/verify_native_ledger_fixture.py \
  runs/5a-native-ledger-1block.sqlite3 \
  data/reference/native_5a_bounded_walk_30400_fixture.tsv
```

## Exact result

The block has three native pair-twist vertices. The 14-bit mask predicate
classifies two as generating. The first produces the complete known component:

- status `closed`;
- 5,498 checked and discovered quotient vertices;
- 30,400 weighted classes;
- exact ordered agreement with the GAP-generated fixture.

The second generating seed is already owned by that certificate and is counted
as one ledger hit. The imported ledger therefore contains one block, one
certificate, and 5,498 uniquely owned vertices. SQLite `quick_check` is `ok`
and `foreign_key_check` is empty. The transcript records the distinct
`native-v1` coordinate convention; it is not append-compatible with the GAP
legacy/key-v2 ledgers by numeric twist ID.

## Timing

The native process used 419,508 KiB maximum RSS. Loading and indexing the
coordinate/mask checkpoints took 1.492 seconds. Block refinement, generation,
the full component walk, ownership insertion, and transcript emission took
1.934 seconds. Importing the 5,498-vertex certificate into SQLite took 0.19
seconds and 17,308 KiB maximum RSS.

A 20-contiguous-block follow-up found 58 refined vertices, 32 generating
vertices, 29 certificates, three ledger hits, and 86,795 uniquely owned
vertices. Its certificate statuses were one `closed`, four `linked`, and 24
`overflow`. It completed the native batch in 20.042 seconds, or 0.998
blocks/second, at 743,444 KiB maximum RSS; SQLite import took 1.09 seconds.
The first certificate again matches the complete ordered GAP fixture. The
other 28 certificates have not yet been independently replayed in GAP, so this
contiguous result is structural and performance evidence, not a new certified
mathematical result. A class-stratified census remains the next timing gate.

## Hybrid measurement rule

`plan_hybrid_shards.py` assigns disjoint deterministic modular shards to CPU
and GPU backends. `summarize_hybrid_throughput.py` compares CPU-only throughput
with simultaneous CPU+GPU throughput and reports both net gain and CPU slowdown.
The GPU need not beat or replace the CPU. It is useful whenever the combined
system produces more independently verifiable work without unacceptable
resource contention or complexity. A 10--20 percent sustained total gain is
already material on a multiweek search.

## Verdict

Passed the fresh native-ledger seam, a 20-block sustained contiguous pilot, and
the additive hybrid-accounting gate. This does not yet establish stratified
native 5A throughput or parallel SQLite commit behavior. CUDA feasibility is
measured separately in test 0039.
