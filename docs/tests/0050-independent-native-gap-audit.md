# Test 0050: independent GAP audit and compact-cursor rehearsal

## Question

Can a verifier that is mathematically independent of the C++ coordinate,
generation-mask, and walk kernels audit native 5A certificates and sampled
blocks? Can the metadata-only 161,177,452-block cursor resume through real
full-cutoff waves with exact prefix/final replay, bounded WAL, and an
exhaustiveness audit?

## Independent verification boundary

The verifier starts only from the original GAP homogeneous-pair checkpoint and
the immutable SQLite result. GAP independently:

- rebuilds the M23 pair-block locator and lazy double cosets;
- translates native-v1 twist IDs by beta12-orbit membership and stable least
  relative index, without reading the native coordinate checkpoint;
- tests `Group(tuple) = M23` directly, without reading the 14-bit native
  generation masks;
- follows GAP's braid and refinement implementation in native-ID order;
- queries SQLite only for ownership by a strictly earlier certificate ID; and
- compares status, linked owner, checked/discovered counts, weighted classes,
  and the complete ordered vertex list.

The production planner selects every closed and overflow certificate, 256
systematic linked certificates, and 64 systematic completed blocks by default.
For each sampled block GAP independently counts refined and generating
pair-twist vertices, reconciles new certificates plus hits, and requires final
ledger ownership for every generating vertex. The plan freezes the database,
pair-checkpoint, and native work-plan hashes. Deterministic segments compose
only when they cover the exact hashed plan.

This is intentionally a second implementation, not the existing native
strict-prefix replayer. It does not independently repeat every routine linked
certificate or every block; universal generation-mask certification,
coordinate differential tests, native complete replay, the arithmetic
full-cursor audit, all exceptional certificates, and the systematic GAP block
sample are separate gates.

## Inputs and provenance

- implementation: the commit containing this note;
- GAP pair checkpoint SHA-256
  `1d6653fedb4327ed4594a1ca55cad03b82fbcae5a45817dbadeede05902468ea`;
- native coordinate checkpoint SHA-256
  `08b2b789db8e2fc9e00c917ac4f28a750965fe9390e8cae7ae4a793ce9b4cedc`;
- generation-mask checkpoint SHA-256
  `0e39a410106cb5f18dc6f8fca24b702109e4614a35345a3200e2edd519b1fe7b`;
- proof and walk cutoffs 30,400, native convention `native-v1`;
- GAP 4.12.1, g++ 13.3.0, and SQLite 3.45.1 on the 24-thread WSL2 host;
- ignored operational inputs under `runs/` and temporary audit/rehearsal
  artifacts under `/tmp`.

The final all-status audit used the 100-block/two-worker native pilot database,
SHA-256
`4b3e6e66c945fca0dff6737c252756de5f80e4f5d48cce21f65463a4a5e34b40`.
Its audit-plan SHA-256 is
`f32694da191efe75ae393ffe9e29d3151cb0096614e83e80e2be7147f1e0bf95`.
The deliberately reduced gate selected one certificate of each exceptional
status, two systematic linked certificates, and two systematic blocks; the
production defaults remain broader.

## Independent GAP result

Two GAP workers verified four certificates: one closed, one overflow, and two
linked. They reproduced 10,350 ordered certificate vertices exactly, including
both linked certificate IDs and their strict prefixes. The two systematic
blocks contained four independently reconstructed pair-twist vertices; direct
GAP generation classified three as generating, and every generating native
key had final ledger ownership. Stored refined, generating, new-certificate,
and hit counts all agreed.

The composed audit passed SQLite integrity and foreign keys and confirmed no
leases. It took 130 wall seconds including both GAP locator builds. Peak sampled
process-tree RSS was 1,341,408 KiB; available host memory remained above
29,795,816 KiB. A separate single-worker gate reproduced the known complete
5,498-vertex, 30,400-class closed component exactly.

## Compact-cursor resume rehearsal

A fresh two-shard full-cursor descriptor represented all 161,177,452 blocks
with zero materialized scheduling rows. Its plan SHA-256 is
`e4e51c8793536a650dba972a25491b2367bca440d543227facd3386932dda985`.
The first full-cutoff wave scanned 0 to 4 completed blocks in 13 seconds and
then exactly replayed 17 certificates and 42,651 vertices in 16 seconds. It
left 11 overflow and six linked certificates.

The second wave resumed the same ledger from 4 to 8 blocks in 10 seconds. Its
immutable four-block prefix replay took 14 seconds and overlapped all ten scan
seconds; final replay took 12 seconds. No additional certificates were needed
because all generating seeds in the four new blocks already had ownership.
Both waves passed prefix/final checkpoints with zero WAL bytes afterward,
SQLite integrity, exact native replay, frozen modulo-shard ownership, and the
partial arithmetic exhaustiveness audit. Peak process-tree RSS was 625,564 KiB
for the first wave and 1,112,884 KiB for the overlapped second wave.

The final rehearsal ledger has SHA-256
`151819e468b9f4124d8df86ddb8330ce9240b45dba2000aa6af001232c0b3ce5`.
An independent GAP audit bound to that database and compact-plan hash replayed
one 3,012-vertex overflow certificate and reconstructed two blocks with nine
refined/generating vertices; all nine were owned. Its audit-plan SHA-256 is
`1c4c0caf1424d876063fc1ef3f32916dbb7d8e2c1099e4c6925d367f10775cf6`.

Partial wave boundaries are counts rather than a fixed ordinal prefix: a fast
shard may complete more of its permanently assigned modulo sequence before the
global target is reached. Ownership is still deterministic, resumable, and
disjoint. At the final census boundary, primary-key uniqueness, in-range
ordinals, exact per-shard arithmetic counts, and `N` completed rows prove that
every ordinal is present.

## Verdict

Passed the independent GAP closed/overflow/linked certificate gate, systematic
block refinement/generation/ownership gate, compact-cursor full-cutoff resume,
prefix overlap, final replay, checkpoint/WAL, and partial exhaustiveness-audit
gates.

An exhaustive result would additionally require the default independent plan
against the final immutable ledger: every exceptional certificate plus the
full systematic linked/block samples. No exhaustive 5A ledger was produced.
