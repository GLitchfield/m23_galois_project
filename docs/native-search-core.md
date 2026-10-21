# Native search core

The C++ backend described here reached production-shaped rehearsals (tests
0024--0055). The exhaustive 5A census it was built for was not run.

## Purpose

The native code is an optimization backend, not a replacement for GAP's
mathematical role. GAP continues to construct and verify the group-theoretic
tables. Python and SQLite continue to provide durable scheduling and
transactional certificates. C++ is introduced only for measured hot loops
whose inputs can be frozen and whose outputs can be replayed independently.

## Initial exact kernel

`src/native/m23_kernel.*` implements degree-23 permutation composition,
inversion, conjugation, Hurwitz moves, and the three direct pure `B4` moves.
Each permutation occupies exactly 23 bytes and stores zero-based images. The
multiplication convention is deliberately GAP-compatible:

```text
point^(left*right) = (point^left)^right.
```

The checked-in fixture is generated from Seguin's explicit generating tuple by
GAP. The native test compares every coordinate of ordinary, inverse, and pure
Hurwitz moves with GAP, checks direct formulas against braid words, and checks
that product-one is preserved. Invalid public inputs are rejected by fixture
parsing; hot permutation operations assume valid permutations and avoid a
validation scan on every composition.

The fixture now also includes a generating `(4A,4A,2A,2A)` tuple from the
certified production bridge.  Thus the native formulas are differentially
checked on the actual class vector used by the quotient scanner, not only on
the Seguin `(3A)^4` calibration tuple.

Run the complete generator/compiler/checker with:

```bash
make check-native-kernel
```

The same check now regenerates a coordinate micro-checkpoint from production
block `1633430`, pair-twist vertex `1`. GAP exports every materialized tuple in
that vertex, its exact beta13/beta14 images and pair-twist coordinates, and the
ordered neighbor list. It also exports the exact table rows reached in GAP's
coordinate pipeline: target-pair normalization, class-specific right-pair
transport, macroblock segment arithmetic, relative double-coset lookup, and
pair-twist refinement. C++ independently applies the native braid moves and
derives every destination through those compressed tables. An enumerated
moved-tuple index remains in the test only as a second oracle. Both paths check
weights and reproduce the neighbor order. A second real fixture closes the
duplicate-removal gate: block `2`, twist `1` has source weight `2`, but all four
beta13/beta14 images deduplicate to one quotient neighbor. That collision
vertex is non-generating, so it tests the exact coordinate/deduplication layer
rather than a reachable production BFS vertex; a generating collision remains
desirable additional coverage. Both fixtures also check first-seen stability
by replaying their source orbits twice.
`scripts/gap/find_native_coordinate_collision.g` performs the bounded,
deterministic search that found the colliding vertex without involving the
production ledger.

The complete global normalization layer is feasible to freeze: the exact 4A
checkpoint census has 318,780 target-pair rows and 180,465 class-specific
right-pair rows. In the deliberately redundant micro-checkpoint layout these
occupy 45,773,805 raw bytes before hash-container overhead. This does not count
the per-block relative maps and refinements, which should remain lazy rather
than being multiplied across all 7,928,185 macroblocks.

## Data boundary

The production boundary should be a versioned, immutable binary checkpoint,
not an in-process GAP foreign-function interface. A standalone format makes
the implementation easier to audit and lets GAP and C++ run on different
machines. Every file must include:

- schema version and degree;
- source Git revision and GAP version;
- target conjugacy-class identity and class invariants;
- counts and offsets for every packed table;
- a canonical byte order;
- SHA-256 provenance for source and derived files.

The first production schema should contain only tables that profiling proves
are needed by the selected hot kernel. Prematurely serializing GAP objects or
all 161 million `5A` macroblocks would defeat the current symbolic compression.

## Measured porting gates

1. Collect phase profiles from a representative scan wave. **Complete.**
2. Remove nonmathematical bottlenecks before porting a kernel. **Complete.**
   On a mature 425,000-block ledger, an identical 100-block wave fell from
   205.15 seconds to 14.72 seconds after whole-ledger statistics were sampled
   rather than recomputed per block, completed frontier rows were pruned, and
   certificate seeds were indexed. The original GAP phase total was only
   4.75 CPU-seconds, so the first bottleneck was SQLite monitoring rather than
   permutation algebra.
3. Select the remaining dominant pure function. **Measured.** Quotient walking
   accounts for roughly 84--89 percent of profiled GAP time, with refinement
   about 9--13 percent. The expensive boundary includes GAP coordinate lookup
   and relative-double-coset refinement around the already-native braid moves.
4. Export a small set of real `4A` blocks and all GAP results for that function.
   **First production block complete.** The checked-in versioned fixture is
   regenerated from the homogeneous pair checkpoint during native checks.
5. Require byte-for-byte native agreement on every result, including ordering,
   weights, and duplicate removal. **Complete for the initial and naturally
   colliding micro-checkpoints.** More blocks will be added as the compressed
   coordinate tables are ported.
6. Port the coordinate pipeline used by the fixture. **Complete through lazy
   block refinement.** GAP exports every target-pair/right-pair row and
   symbolic segment directly to a versioned little-endian checkpoint. From
   those global rows C++ reconstructs a requested block's product centralizer,
   stabilizers, key-v2 relative double cosets, beta12/beta34 actions, and
   pair-twist weights. Both differential fixtures preserve the GAP partition
   and neighbor collision behavior. The complete global files are 45,774,292
   bytes for 4A and 131,381,583 bytes for 5A.
7. Measure CPU time, wall time, and peak memory. **Complete for global export,
   load, and first-block-per-class refinement.** A conservative export
   measurement alongside eight production workers took 21.74 seconds and
   188,924 KiB maximum per-process RSS for 4A; the full 5A export took 76.13
   seconds and 311,120 KiB. Loading that 5A file and reconstructing one block
   in every non-identity product class took 7.19 seconds including compilation,
   at 324,640 KiB maximum RSS. Test 0037 subsequently measures complete
   component walks; test 0038 adds a 20-block contiguous ledger pilot, and test
   0040 measures the class-stratified census.
8. Port bounded BFS only if the kernel speedup survives end-to-end integration.
   **Full-cutoff differential complete.** C++ lazily constructed all
   destination blocks reached at both the 250- and 2,500-class cutoffs. At the
   full proof cutoff it reproduced GAP's ordered 261-vertex, 2,504-class
   overflow result. The measured native process was substantially faster.
   Test 0038 subsequently added the generation, ownership, transcript, and
   SQLite import seams plus a 20-block contiguous pilot; test 0040 adds bounded
   stratified execution and an arithmetic runtime model.
9. Accept native certificates only after independent GAP replay.

Native twist IDs deliberately form a new coordinate convention: beta12 orbits
are numbered by increasing least key-v2 relative index. GAP's older numeric IDs
depend on its double-coset representative order. The orbit partitions and
weights agree, but a native ledger cannot append to a GAP `legacy`/`key-v2`
ledger merely because both use integers. Integration must record a distinct
native convention and begin a fresh ledger, with GAP replay translating by
orbit membership rather than assuming ID equality.

The identity-product macroblock now has an equally stable native convention.
Its pair-twist vertices are singletons, indexed by the existing target-pair
orbit key `(product_class, pair_id)`. This avoids an M23-sized transporter
table. A complete known 5A component crosses this block at 28 vertices and the
native walk reproduces all 5,498 quotient vertices and 30,400 weighted classes.
The cold walk takes 1.77 seconds after global index construction; see test
0037.

An eight-worker 10,000-block wave now reaches 55.2 blocks/second with the GAP
mathematics unchanged. Connecting only the existing C++ move kernel would add
an interprocess boundary while leaving coordinate lookup in GAP, so that
partial integration is deliberately rejected. The first fresh native ledger
now combines the measured walk, generation masks, external ownership lookup,
deterministic certificate emission, and SQLite import. Its complete
5,498-vertex certificate matches the ordered GAP fixture. A 20-block follow-up
processed 86,795 owned vertices at 0.998 blocks/second, but only its first
certificate has independent GAP replay. The deterministic 80-block census in
test 0040 samples five systematic positions in every nonidentity product-class
segment. Clearing disposable block tables after each certificate reduced peak
RSS to 458,880 KiB and projected a 1.158 single-core-day arithmetic floor,
with 1.021--1.321 days across the five sample positions. A direct sparse-block
extrapolation is invalid because sparse samples repeatedly traverse components
that a durable ledger owns once. Test 0042 now connects those operations to the
existing WAL schema directly from C++. Two deterministic workers resumed a
shared ledger to 100 blocks, 106 certificates, and 140,773 unique vertices at
about 0.75 GiB aggregate RSS. An intentional exit after the known 5,498-vertex
certificate commit left no partial state and recovered to the exact GAP
fixture. Test 0043 processes the exact 80-block stratified plan through live
SQLite: 152.50 seconds sequentially with row-for-row agreement against the
imported transcript, and 65.16 seconds with four workers at 1.51 GiB peak
aggregate RSS. This produced a provisional 15--20-hour scan estimate, later
retired by the direct full-cursor measurement in test 0051. The next
test replays all 3,657 concurrent certificates against their strict earlier-ID
ownership prefixes: all 1,180,560 ordered vertices agree in 133.35 seconds.
Test 0046 implements that deterministic scheduling seam. Small sampled plans
store ordinals with fixed shard IDs and retain a barrier against discovered
frontier work. Fixed-shard scan and immutable-range replay harnesses compile
their native binary once. Test 0047 passes the 800-block four-shard
forced-interruption/resume gate and exactly replays all 45,606 certificates.
Balancing immutable replay ranges by stored vertices plus the measured
per-certificate cost reduces the slowest range from 263 to 158 seconds.
Test 0048 then completes an 8,000-block no-fault wave and exactly replays
13,931,530 vertices. It initially supported a provisional 21--26-hour native
scan-plus-replay envelope, but its deliberately stratified block rate could
not be multiplied across the full census; test 0051 now retires that envelope.

The original mixed-wave backup in test 0048 was consistent but chased active
WAL writes: it began at the 2,000-block trigger and captured 7,504 blocks while
pinning a large WAL. Test 0049 makes the boundary exact. The committed harness
finishes its first deterministic scan wave, checkpoints and truncates the WAL,
takes and validates a quiescent backup, then starts prefix replay alongside the
second wave. It checkpoints again before final hashing and complete
cost-balanced replay. A 16-block two-scan/two-replay lifecycle smoke captures
exactly four requested prefix blocks and finishes with zero WAL bytes after
both checkpoints.

Small stratified experiments still use explicit planned rows. The production
census instead uses `m23-native-full-cursor-plan-v1`: a hashed descriptor
freezes the source checkpoint, 161,177,452-block extent, start ordinal, shard
count, and `ordinal-modulo-v1` ownership. Per-shard cursors are durable ledger
metadata, so no frontier or plan row is needed before a block is claimed. The
completion auditor requires exactly `N` primary-key-distinct, in-range block
rows, arithmetic shard ownership, no leases, and clean SQLite integrity. These
conditions are an exhaustiveness certificate because `N` distinct values in
the `N`-element ordinal range cannot omit an ordinal. A one-million-row
storage benchmark projects that the compact plan avoids 10.9 GiB of redundant
SQLite scheduling tables. Test 0050 adds the separate mathematical verifier:
GAP rebuilds the pair locator from the original checkpoint, maps native IDs by
orbit membership, tests generation directly, and queries SQLite only for
strict earlier-certificate ownership. It passes all three certificate statuses
and sampled block refinement/generation/final-ownership checks. The resumable
full-cursor launcher also passes two real full-cutoff waves with exact
prefix/final replay and bounded WAL. A production result would have required
the default audit of every exceptional certificate plus 256 systematic linked
certificates and 64 systematic blocks against the final immutable ledger;
isolated permutation microbenchmarks are not used to project `5A` runtime.

Test 0051 exercises that complete interface at a population-cursor boundary.
A fresh four-shard ledger reaches 2,000 blocks, then resumes to 10,000 while a
97-second exact prefix replay overlaps the 169-second second-wave scan. The
resumed interval sustains 47.34 blocks/second; final replay verifies 29,276
certificates and 3,477,384 vertices in 257 seconds. Peak overlapped RSS is 2.15
GiB on the 32-GiB WSL2 instance. The production-default independent GAP audit
then verifies both closed and all 40 overflow certificates, 256 linked
certificates, and 64 blocks. A direct linear scan projection is 39.4 days at
four workers, consistent with the four-to-five-week scan model and decisively
inconsistent with the retired 15--20-hour stratified estimate. Maturation can
change frontier density and ownership reuse, so this is a sizing measurement,
not a completion guarantee. The equal-boundary eight-worker repetition in test
0052 passes every correctness and resource gate, but its partial cursor reaches
ordinal 1 while the four-worker cursor does not. That identity block alone
takes 329.599 seconds and emits 28,012 certificates. Since changing the shard
count changes frontier order, this is not a controlled speed comparison; the
same 8,000 committed stratified ordinals must be run at both worker counts.
Test 0053 performs that comparison. Eight workers reduce scan wall time from
2,145 to 1,825 seconds, but aggregate block time rises from 8,438.953 to
14,123.826 CPU-seconds. The class-2 mean rises from 15.151 to 25.301 seconds,
with most workers observed in SQLite retry sleep behind its single-writer
transaction. The exact ordinals and block invariants match, as do all three
closed-component vertex sets. Raising a fixed worker count therefore does not
scale the certificate-heavy strata; test 0055's queued single writer did not
fix this either. The independent audit planner now also assigns
certificates longest-estimated-work first across its frozen job count. On the
10,000-block ledger this separates the two closed components and balances the
four modeled segment costs within 0.5 percent.

## Fixed-first generation masks

For 5A, a fixed target belongs to exactly 14 maximal-subgroup conjugates.
Every target-class element therefore receives a 14-bit incidence mask, and a
normalized tuple generates M23 exactly when its four masks have bitwise
intersection zero. The subgroup list is enumerated explicitly and each
incidence count is checked independently by subgroup-class double counting.

The GAP predicate agrees with direct `Group(tuple) = M23` on 3,089
representatives spanning the first block of all 16 nonidentity product
classes. A versioned native export stores 680,064 masks in coordinate-target
row order; the whole artifact is 1,360,311 bytes including provenance and an
ordered-row fingerprint. C++ loads it, verifies target-class alignment, and
reproduces the 1,626 generating representatives. See test 0036. This removes a
small irregular group-closure
operation, but generation was only about 10.5 percent of the measured cold 5A
block kernel.
