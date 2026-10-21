# Sharded `(C,C,2A,2A)` engine

## Purpose

The engine generalizes the successful `(4A,4A,2A,2A)` computation to the known
bridge vectors for `5A`, `6A`, and `8A`. It enumerates generating inner Nielsen
classes and constructs the complete pure and symmetric braid actions. It does
not search `(C,C,C,C)` directly; the homogeneous bounded search in
[`bounded-search.md`](bounded-search.md) is a separate layer.

## Shard invariant

After fixing `s1` in `C`, every tuple is determined by an ordered involution
pair `(s3,s4)`:

```text
s2 = s1^-1 (s3 s4)^-1.
```

The quotient group `C_M23(s1)` acts simultaneously on all four coordinates.
Sharding individual `s3` values would break quotient orbits across files.
Instead, the engine computes the complete centralizer-orbits on the 3,795
involutions and assigns those whole orbits to shards. Thus:

- every possible `s3` occurs in exactly one shard;
- each shard's candidate set is invariant under simultaneous conjugation;
- every product-one inner class belongs to exactly one shard;
- shard results can be filtered for generation independently;
- merging requires no cross-shard deduplication when checkpoints are valid.

Orbit IDs are assigned to shards by deterministic greedy balancing: process
centralizer-orbits by decreasing size, breaking ties by orbit ID, and place the
next orbit in the currently lightest shard (lowest index breaks weight ties).

## Running a search

```sh
M23_JOBS=4 ./scripts/run-sharded-cc2a2a.sh \
  CLASS_ORDER SHARD_COUNT RUN_DIR RESULT.tsv CERTIFICATE.tsv
```

For example, a local 16-shard `5A` bridge run would use:

```sh
M23_JOBS=4 ./scripts/run-sharded-cc2a2a.sh \
  5 16 runs/5a-bridge runs/5a-bridge-result.tsv runs/5a-bridge-certificate.tsv
```

`M23_JOBS` controls concurrent local GAP processes and defaults to 1. Memory,
not only CPU count, should determine this value.

## Unattended runs and progress

Use the management wrapper for a long search that should survive an ordinary
terminal disconnect and be inspectable without an interactive assistant:

```sh
./scripts/manage-cc2a2a-run.sh start CLASS_ORDER SHARD_COUNT RUN_DIR JOBS
./scripts/manage-cc2a2a-run.sh status RUN_DIR
```

The first command launches a new process group with `nohup`. The second is a
read-only, constant-cost summary of the managed PID, completed checkpoints,
representative validation, deep recount, certificate, merge, latest event, and
log size. For a continuously refreshing terminal view, use:

```sh
watch -n 10 ./scripts/manage-cc2a2a-run.sh status RUN_DIR
```

Progress is appended to `RUN_DIR/progress.tsv`; ordinary program output goes to
`RUN_DIR/runner.log`. Both are ignored operational files. Verification records
one event after each shard's representatives are checked and another after its
full independent recount, so even the long single-process certification phase
has visible coarse-grained progress.

For a local browser view across one or more run directories, see
[`monitoring.md`](monitoring.md). The dashboard reads these same durable files
and has no run-control endpoints.

To wait without polling or to interrupt the complete process group safely:

```sh
./scripts/manage-cc2a2a-run.sh wait RUN_DIR
./scripts/manage-cc2a2a-run.sh stop RUN_DIR
```

`stop` sends `SIGINT`; completed checkpoints remain usable and incomplete
checkpoint/certificate writes retain their atomic temporary-file behavior.
Running `start` again with the same parameters resumes from those checkpoints.
The wrapper writes final copies as `published-result.tsv` and
`published-certificate.tsv` inside the run directory.

## Resume behavior

Each checkpoint is written to a temporary sibling and atomically renamed only
after its record header and shard index are confirmed. Re-running the same
command retains nonempty checkpoint paths and reports `resume: keeping ...`.
The independent verifier then validates every retained checkpoint before merge;
changing the class order, shard count, assignment algorithm, or checkpoint set
causes verification to fail.

If a checkpoint is known to be bad, move it aside rather than editing it. The
next invocation will regenerate the missing canonical path.

## Checkpoint contents

Each GAP-readable checkpoint records:

- schema and GAP versions;
- group and target-class order;
- shard count/index;
- total centralizer-orbit count and assigned orbit IDs;
- assigned third-coordinate count;
- product tuple, product inner-class, and generating inner-class counts;
- one fixed-first representative for every generating inner class.

Checkpoints live under ignored `runs/` by default. They are operational state,
not final research artifacts.

## Verification and merge

The independent checkpoint verifier:

- proves shard indices and centralizer-orbit assignments form exact partitions;
- checks product-one, class membership, and generation for every representative;
- reconstructs each centralizer orbit and checks its expected size;
- rejects duplicate inner classes within or across checkpoints;
- independently re-enumerates every assigned involution pair and recomputes the
  product-tuple, product-orbit, and generating-orbit counts;
- confirms every generating class found by the deep recount is checkpointed;
- emits a compact coverage certificate.

Only after that pass does the merger independently rebuild the fixed-first
dictionary and compute `beta12`, `beta13`, `beta14`, `beta4`, and `eta34`.
It records pure and symmetric orbit sizes and a genus for each connected orbit,
plus complete generator cycle shapes.

The run directory receives `SHA256SUMS` covering all checkpoints, the
certificate, and the merged result.

## Regression result

The committed four-shard `4A` certificate covers all 144 centralizer-orbits and
all 3,795 involutions exactly once. Its totals and complete braid actions match
the separately implemented monolithic computation byte-for-byte at the field
level: 609,553 product tuples, 19,609 product inner classes, 2,456 generating
classes, one pure orbit, and genera 447/169.
