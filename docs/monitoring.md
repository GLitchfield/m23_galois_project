# Local run dashboard

Long computations expose progress through append-only `progress.tsv` events,
atomic shard checkpoints, certificates, results, PID files, and ordinary text
logs. The dashboard is a read-only view of those files. It is not part of a
mathematical certificate and cannot change a run.

## Start it

From the repository root:

```sh
make dashboard
```

Then open `http://127.0.0.1:8765`. The default watches `runs/` recursively.
To watch other directories or choose another port:

```sh
python3 scripts/m23_dashboard.py --port 9000 runs /tmp/research-runs
```

The server binds only to `127.0.0.1` unless `--bind` is explicitly supplied.
It has no authentication, so do not expose it on a network interface without a
separate access-control layer.

## Displayed state

The browser discovers both managed event directories and older directories
that contain certificates or results. It polls every three seconds and shows:

- a layered overall 4A coverage bar separating verified, checkpoint, and
  speculative blocks;
- current-wave progress, measured scan rate and ETA, ledger size, and
  generating-vertex reuse;
- certificate and block-segment progress for the pending independent replay;
- native stratified-batch sampled-block progress, latest block time,
  certificate count, and owned-vertex count from flushed `runner.log` rows;
- managed process state and latest durable event; unmanaged multi-worker runs
  are shown as running while they continue to emit fresh nonterminal events;
- checkpoint, representative-verification, and deep-recount counts;
- elapsed time and time since the last event;
- certificate, merge-result, and failure state;
- recent events and an on-demand tail of `runner.log`.

Database-backed quotient scans also report ledger vertices, pending frontier
blocks, certificate counts, and logical database size in their latest event.
Multi-worker runs share those events and keep per-worker ordinary output in
`worker-N.log`; certificate and block counters always come from the shared
transactional database rather than summing worker logs.

Scan waves can emit low-frequency cumulative phase profiles by setting
`M23_PROFILE_INTERVAL` to a positive block count. These events do not affect
the mathematical ledger. Summarize them with
`python3 scripts/summarize_quotient_profile.py RUN_DIR/progress.tsv`. The
measured phases are block claim, refinement, seed generation/lookup, quotient
walk, certificate commit, and block completion/statistics, in GAP process CPU
milliseconds; test 0026 reports the resulting profile.

A long single-worker database scan can be detached and managed with:

```sh
./scripts/manage-db-quotient-run.sh start PAIR FIRST LAST START PROOF WALK RUN_DIR BLOCK_BUDGET
./scripts/manage-db-quotient-run.sh status RUN_DIR
./scripts/manage-db-quotient-run.sh stop RUN_DIR
```

Stopping sends `SIGINT` to the process group. Already committed SQLite
transactions remain valid; an unfinished block is selected again on restart.

Prepared multi-worker quotient ledgers have a corresponding manager:

```sh
./scripts/manage-parallel-quotient-run.sh start \
  PAIR FIRST LAST START PROOF WALK RUN_DIR WORKERS VIRTUAL_SHARDS TARGET \
  TRAVERSAL_ORDER
```

The existing pipelined candidate runner requires the ledger's explicit
`TRAVERSAL_ORDER` as its final argument and passes it to both replay and scan
workers. It samples both process trees into `resource-samples-to-TARGET.tsv`.
This records aggregate RSS, process counts, available system memory, and free
swap at a configurable `M23_RESOURCE_SAMPLE_SECONDS` interval without
inspecting mathematical state.
For a bounded coexistence experiment on already prepared candidate and live
ledgers, `scripts/run-mixed-quotient-pilot.sh` starts both sides and records the
same separate process-tree metrics. It is an experiment harness, not a
candidate-promotion command.

The ETA is specific to the current database scan invocation. It uses the
measured block rate since that invocation started and does not mix scan,
certificate replay, or block-reconciliation phases. It will be unstable during
worker startup and after a resume, then becomes more useful as the sample grows.

## Machine-readable status

The existing CLI output remains stable:

```sh
python3 scripts/m23_run_status.py runs/4a-sharded
```

The same collector also provides JSON:

```sh
python3 scripts/m23_run_status.py --json runs/4a-sharded
```

The dashboard serves `GET /api/runs` and bounded `GET /api/log` requests.
Mutation requests are rejected with HTTP 405.
