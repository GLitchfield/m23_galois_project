# Test 0054: complete bounded 4A search

## Question

After every symbolic pair-pair macroblock, including the exceptional
identity-product block, is covered, what is the exact bounded pure-component
set `B4((4A)^4,2500)`? Does a direct tuple-level computation independently
confirm every closed component reported by the quotient ledger?

## Inputs and provenance

- nonidentity production/scanner revision
  `60612c4dff739ed5cb449820b0d8bb94ad77071d`;
- special-block queue and final-audit revision
  `d3b0f646a6ce5c92e6847f45d471b3391e87d959`;
- schema-2 pair checkpoint `runs/4a-pair-orbits-v2.g`, SHA-256
  `add26b95401d74fbaf29167782667080275d848b8cddabceecef40c2051c75c4`;
- exactly replayed 7,928,184-nonidentity-block base, SHA-256
  `7061e55ccdfa7ffac9532e5520fd10da390eef265136f186e7463fe3aa6fabaa`;
- proof limit 2,500, coverage-walk limit 25,000, frontier schedule starting at
  ordinal 1,633,430, and legacy deterministic traversal order;
- GAP 4.12.1 with AtlasRep 2.1.8, CTblLib 1.3.7, and TransGrp 3.6.5; and
- ignored operational inputs and outputs under `runs/`, with the final
  read-only snapshot at `runs/4a-db-base-complete-7928185/`.

The 4A pair checkpoint contains 10,099 pair orbits and 7,928,185 symbolic
macroblocks. Production deliberately scanned ordinals 2 through 7,928,185;
ordinal 1 is the structurally different identity-product block.

## Identity-block correction

The first final audit disproved the assumption that nonidentity coverage would
already own every generating identity vertex. The identity block has 10,099
singleton quotient vertices. Direct GAP generation tests found 4,976 generating
vertices, but the exactly replayed nonidentity ledger owned only 500 of them.
The missing 4,476 vertices were a real exhaustiveness gap, so the nonidentity
snapshot is retained as provenance but is not the final result.

The tested `ENQUEUE_SPECIAL` ledger operation queued ordinal 1 without changing
the immutable nonidentity base. Scanning that block added exactly 4,476
certificates. Every added certificate had status `linked`; no new closed or
overflow component appeared. The operational commands were:

```sh
./scripts/enqueue-special-quotient-block.sh \
  runs/4a-db-live-complete-7928185/ledger.sqlite3 \
  1 4 2 7928185 2 7928185 2500 25000 frontier 1633430

M23_TRAVERSAL_ORDER=legacy \
  ./scripts/scan-direct-pair-quotient-db.sh \
  runs/4a-pair-orbits-v2.g 2 7928185 2500 \
  runs/4a-db-live-complete-7928185 frontier 1633430 1 25000
```

The appended certificate range and ordinal-1 block were then replayed against
the immutable nonidentity base with
`verify-direct-pair-quotient-db-delta.sh`. Replay reproduced all 4,476
certificates and finished at exactly 10,826,112 owned vertices.

## Independent final audit

The final command was:

```sh
./scripts/audit-complete-4a-bounded-search.sh \
  runs/4a-pair-orbits-v2.g \
  runs/4a-db-base-complete-7928185/ledger.sqlite3
```

The audit does not trust the block counters for the identity conclusion. It
reconstructs all 10,099 identity tuples, checks target-class membership and
product one, calls GAP's group-generation test on each tuple, and looks up its
stable quotient key in the read-only ledger. It found all 4,976 generating
vertices owned, zero generating vertices missing, and zero nongenerating
vertices owned.

For each of closed certificates 781, 1396, and 15731, the audit independently
materializes its recorded tuple seed and performs an uncontracted fixed-first
pure-braid breadth-first enumeration. Each orbit closes at exactly 2,456 inner
classes, and a separate tuple dictionary proves the three enumerated orbits are
pairwise disjoint.

## Result

The final ledger contains:

| Metric | Value |
| --- | ---: |
| Processed macroblocks | 7,928,185 |
| Certificates | 5,349,177 |
| Owned quotient vertices | 10,826,112 |
| Closed certificates | 3 |
| Overflow certificates | 4 |
| Linked certificates | 5,349,170 |
| Generating identity vertices | 4,976 |
| Owned generating identity vertices | 4,976 |
| Direct closed-component sizes | 2,456, 2,456, 2,456 |

The immutable 1,192,366,080-byte ledger has SHA-256
`c638c0aa0fe4918b2c86c0ea446e8591fd250ee0de21ba12cab570cf523a6835`.
Its manifest records exact certificate-order replay and zero missing blocks.

Therefore

```text
B4((4A)^4,2500) = X1 disjoint-union X2 disjoint-union X3,
|X1| = |X2| = |X3| = 2456.
```

Every other generating inner class has a replayable connected witness of 2,501
classes and hence lies in a pure component larger than 2,500. This is a bounded
classification statement; it does not claim the exact sizes or number of the
larger components.

## Verdict

Passed the full macroblock census, exact identity-delta replay, direct identity
generation/ownership audit, direct closed-orbit reconstruction, pairwise
disjointness, and immutable-snapshot gates. A compact proof package was later
published separately; see `docs/bounded-search.md`.
