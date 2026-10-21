# Test 0031: bounded streaming replay and traversal determinism

## Question

Can an independently replayed `(5A)^4` quotient ledger remain bounded in RAM,
compose across several verifier processes, and reproduce the scanner's exact
certificate identities after coordinate caches are discarded?

## Inputs and provenance

- implementation: the commit containing this note, based on
  `c209e47422fb5e5f4976c6cfda86d12689a92d95`;
- schema-v2 5A pair checkpoint SHA-256
  `1d6653fedb4327ed4594a1ca55cad03b82fbcae5a45817dbadeede05902468ea`;
- proof and walk limits: 30,400;
- deterministic pilot seed block: 71,532,995;
- GAP 4.12.1, Python 3, and SQLite on the 32 GiB workstation.

The pilot database and timing logs are operational artifacts under `runs/` and
`/tmp`, not committed results. The committed scripts reproduce every check.

## Design

Certificate replay previously loaded every prior quotient vertex into one GAP
dictionary. The new default asks the read-only SQLite service for ownership at
or before `certificate_id - 1`. This preserves the original prefix semantics
without retaining a prefix-sized in-process object. A memory mode remains for
matched regression comparisons.

Block replay now streams assigned block rows from SQLite. A second read-only
connection services nested vertex-owner lookups while the first streams rows,
and SQL independently recomputes each block's actual certificate count.
Planning, snapshot counts, final event composition, and ownership audit also
iterate rather than materializing complete result sets.

The exercise found a separate determinism defect. GAP's double-coset list order
can depend on prior group-computation and cache history. Sorting final neighbor
keys (`key-v1`) was insufficient because relative indices, and therefore twist
IDs, could already differ. `key-v2` explicitly chooses the least permutation in
each relative double coset, sorts those canonical representatives before
assigning indices, and sorts neighbors by durable `(block ordinal, twist ID)`.
Ledger metadata records `legacy`, `key-v1`, or `key-v2`; a verifier refuses a
mismatched convention. Existing 4A ledgers are deliberately marked `legacy`.

## Determinism checks

A five-coordinate 5A regression constructed signatures in forward order,
cleared both block-local caches, and reconstructed them in reverse order. All
five key-v2 signatures agreed in 53.54 seconds with 639,112 KiB maximum RSS.
The 4A direct-coordinate regression likewise reconstructs an exact sorted
neighbor list across a cache reset. C++ reproduces the regenerated key-v2
coordinate fixtures, including the genuine four-to-one collision, and the 5A
global-table census remains unchanged.

This versioning is not cosmetic. A key-v1 pilot replayed certificates 1--21
sequentially but failed in an independently started segment at certificate 17
because the exact vertex set changed. That pilot is retained only as an
obsolete diagnostic under `runs/`. The failure motivated key-v2 and prevents
old ambiguous artifacts from being mistaken for new proof data.

After generating the schema-v2 checkpoint as in test 0029, reproduce the cold
coordinate-order check with:

```bash
M23_PAIR_CHECKPOINT=runs/5a-pair-orbits-v2.g \
  gap --quitonbreak -q scripts/gap/check_5a_coordinate_cache_determinism.g
```

## End-to-end 5A pilot

The fresh key-v2 scanner stopped at a clean boundary with SQLite
`quick_check = ok`, zero leases, six completed blocks, 24 committed
certificates, and 52,546 owned quotient vertices. Its first known closed
30,400-class component used 5,498 quotient vertices, 92.44 seconds, and 791,188
KiB maximum RSS.

The certificate planner divided all 24 certificates by
`max(checked_vertices,1) + discovered_vertices`. Four independently started
workers reset their coordinate caches after every certificate and used only
database-backed prefix lookup:

| segment | certificate IDs | vertices | elapsed | maximum RSS |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 1--3 | 11,602 | 147.35 s | 781,352 KiB |
| 2 | 4--10 | 12,934 | 133.95 s | 650,816 KiB |
| 3 | 11--15 | 14,598 | 148.45 s | 651,904 KiB |
| 4 | 16--24 | 13,412 | 163.47 s | 684,820 KiB |

All segments passed, including certificate 17. Their status totals are exactly
one closed, 13 overflow, and ten linked certificates, and their 52,546 vertex
sum equals the database count. The slowest segment determines 163.47 seconds
of replay wall time. Streaming block verification independently rematerialized
all six completed blocks, finding 18 refined vertices, 14 generating vertices,
and seven ledger hits in 33.21 seconds at 554,296 KiB maximum RSS.

A late 4A certificate gives the clearest scaling comparison. Replaying
certificate 1,140,761 against a 4,902,148-vertex prefix took 7.68 seconds and
240,076 KiB in database mode, compared with 27.60 seconds and 1,066,264 KiB in
the old memory mode. Prefix size is no longer a verifier RAM term.

## Capacity conclusion

Bounded replay removes the projected roughly 60 GiB single-dictionary failure
mode. On the pilot, a certificate worker stayed below 0.8 GiB and block replay
below 0.6 GiB. The projected full 5A SQLite ledger is still roughly 20--25 GB,
but it is disk-backed and can use the operating-system page cache opportunistically.

The existing 32 GiB box can therefore produce an exact result with a measured
worker cap; 128 GiB is not required for correctness. It would nevertheless be
valuable operational headroom for a 12-scan plus 4--8-replay pipeline, keeping
most or all of the projected ledger hot while leaving room for native-build and
research experiments. With 24 logical CPUs, CPU throughput becomes the next
limit, so extra RAM should be justified by reliability and cache residency, not
as a promise of a twofold speedup.

## Verdict

Passed the bounded-memory, composable replay, and cache-independent traversal
gates on a real 5A ledger. A sustained mixed scan/replay wave remains required
before choosing the production worker split, but verifier memory no longer
blocks the preliminary five-to-seven-week end-to-end plan.
