# Reproducibility conventions

## Tracked results

Compact, completed results belong in `data/derived/` together with enough
metadata to reproduce and verify them. Each published result should identify:

- the exact command and code revision;
- GAP and package versions;
- input parameters and deterministic shard identifier;
- tuple/orbit counts and elapsed time;
- SHA-256 hashes of result and certificate files.

## Local run data

Incomplete runs, logs, and checkpoints belong under `runs/` and are ignored by
Git. A result should move into tracked data only after an independent checker
accepts it.

Reference inputs live under `data/reference/` and are treated as read-only.
Reproducible transformations belong under `data/derived/`; disposable caches
belong under ignored `data/processed/`. The `runs/` directory (about 43 GB on
the development machine) is not published.

## Baseline checks

Run `make test` before each commit. It verifies dependencies, compact
certificates, provenance, formulas, committed-data manifests, and bounded
self-tests. It deliberately does not regenerate every exhaustive orbit and
census: those computations already publish independently checked certificates,
and replaying all of them after an unrelated edit obscures failures and wastes
substantial time.

Run `make test-replay` when an orbit/census generator, its mathematical kernel,
or a certified result changes. It first runs `make test`, then performs the
exact medium-size GAP reproductions and byte comparisons, including the
reference data, the early 14A/15A/8A/4A orbits, both exhaustive Seguin 3A
certificates, the König orbit, and the deterministic 4A shard integration
test. The replay checks the derived-data manifest once rather than repeating
identical work.

Run `make test-long` for the extended local regression, including
`make test-replay`, the full 5A and 6A bridge recomputations, and the native 5A
walk. Individual `make check-*` targets remain available for focused exact
reproduction, and retain their standalone integrity checks.

Run `make reproduce-notes` deliberately when a dependency upgrade changes an
expected note, then inspect the resulting diff before committing it.

## Sharded computations

Long fixed-first runs partition complete centralizer-orbits rather than raw
tuple indices. Checkpoints are atomically written under ignored `runs/`; a run
is publishable only after the independent shard verifier proves exact assignment
coverage and global representative uniqueness. Preserve the run-directory
`SHA256SUMS` with any archived checkpoints and publish the compact certificate
with the merged result. See `sharded-engine.md` for the operational protocol.
