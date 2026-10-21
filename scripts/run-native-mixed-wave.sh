#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 9 ]]; then
  echo "usage: $0 COORDINATES MASKS RUN_DIR SAMPLES SCAN_WORKERS SNAPSHOT_BLOCKS REPLAY_WORKERS PROOF WALK" >&2
  exit 2
fi

coordinates=$(realpath "$1")
masks=$(realpath "$2")
run_dir=$3
samples=$4
scan_workers=$5
snapshot_blocks=$6
replay_workers=$7
proof=$8
walk=$9
target=$((16 * samples))
writer_mode=${M23_NATIVE_WRITER_MODE:-direct}
case "$writer_mode" in
  direct) scan_command=./scripts/run-native-sqlite-workers.sh ;;
  queued) scan_command=./scripts/run-native-sqlite-queued-workers.sh ;;
  *)
    echo "invalid native writer mode: $writer_mode" >&2
    exit 2
    ;;
esac
for value in "$samples" "$scan_workers" "$snapshot_blocks" \
    "$replay_workers" "$proof" "$walk"; do
  [[ "$value" =~ ^[1-9][0-9]*$ ]] || {
    echo "invalid positive integer: $value" >&2
    exit 2
  }
done
(( walk >= proof && snapshot_blocks < target )) || {
  echo "invalid mixed-wave bounds" >&2
  exit 2
}
mkdir -p "$run_dir"
for path in plan.tsv ledger.sqlite3 progress.tsv result.json; do
  [[ ! -e "$run_dir/$path" ]] || {
    echo "refusing nonfresh mixed-wave directory: $run_dir" >&2
    exit 2
  }
done

echo "$$" >"$run_dir/runner.pid"
touch "$run_dir/progress.tsv"
emit() {
  printf '%s\tnative-mixed\trun\tall\t%s\t%s\n' \
    "$(date +%s)" "$1" "$2" >>"$run_dir/progress.tsv"
}
monitor_pid=0
sampler_pid=0
scan_pid=0
snapshot_replay_pid=0
cleanup() {
  local status=$?
  trap - EXIT INT TERM
  for pid in "$snapshot_replay_pid" "$scan_pid" "$monitor_pid" "$sampler_pid"; do
    if (( pid > 0 )); then
      kill "$pid" 2>/dev/null || true
    fi
  done
  for pid in "$snapshot_replay_pid" "$scan_pid" "$monitor_pid" "$sampler_pid"; do
    if (( pid > 0 )); then
      wait "$pid" 2>/dev/null || true
    fi
  done
  if (( status != 0 )); then
    emit failed "exit=$status"
  fi
  exit "$status"
}
trap cleanup EXIT INT TERM

started=$(date +%s)
runner_revision=$(git rev-parse HEAD)
runner_dirty=0
[[ -z "$(git status --short)" ]] || runner_dirty=1
emit start "blocks=$target,scan_workers=$scan_workers,replay_workers=$replay_workers,writer_mode=$writer_mode,revision=$runner_revision,dirty=$runner_dirty"
M23_NATIVE_PLAN_ONLY=1 scripts/run-native-ledger-batch.sh \
  "$coordinates" "$masks" --stratified "$samples" "$proof" "$walk" \
  "$run_dir/plan.tsv"
python3 scripts/seed_native_stratified_frontier.py \
  "$run_dir/ledger.sqlite3" "$run_dir/plan.tsv" \
  --shards "$scan_workers" --initialize --start-ordinal "$proof"

python3 scripts/monitor_native_sqlite_ledger.py \
  "$run_dir/ledger.sqlite3" "$target" --interval 5 &
monitor_pid=$!
python3 scripts/sample_process_trees.py "$run_dir/resource-samples.tsv" \
  "$$" --labels mixed --interval 5 &
sampler_pid=$!

scan_started=$(date +%s)
"$scan_command" \
  "$coordinates" "$masks" "$run_dir/ledger.sqlite3" "$run_dir/scan-wave-1" \
  "$scan_workers" "$snapshot_blocks" "$proof" "$proof" "$walk" 60 &
scan_pid=$!
wait "$scan_pid"
scan_pid=0
wave_1_finished=$(date +%s)
python3 scripts/checkpoint_sqlite_ledger.py \
  "$run_dir/ledger.sqlite3" >"$run_dir/checkpoint-prefix.json"

snapshot="$run_dir/snapshot-$snapshot_blocks.sqlite3"
snapshot_started=$(date +%s)
python3 scripts/snapshot_sqlite_ledger.py \
  "$run_dir/ledger.sqlite3" "$snapshot" >"$run_dir/snapshot.json"
(
  ./scripts/run-native-sqlite-replay-workers.sh \
    "$coordinates" "$snapshot" "$run_dir/snapshot-replay" "$replay_workers"
  date +%s >"$run_dir/snapshot-replay.finished"
) &
snapshot_replay_pid=$!

wave_2_started=$(date +%s)
"$scan_command" \
  "$coordinates" "$masks" "$run_dir/ledger.sqlite3" "$run_dir/scan-wave-2" \
  "$scan_workers" "$target" "$proof" "$proof" "$walk" 60 &
scan_pid=$!
wait "$scan_pid"
scan_pid=0
scan_finished=$(date +%s)
wait "$snapshot_replay_pid"
snapshot_replay_pid=0
snapshot_replay_finished=$(<"$run_dir/snapshot-replay.finished")
python3 scripts/checkpoint_sqlite_ledger.py \
  "$run_dir/ledger.sqlite3" >"$run_dir/checkpoint-final.json"

final_replay_started=$(date +%s)
./scripts/run-native-sqlite-replay-workers.sh \
  "$coordinates" "$run_dir/ledger.sqlite3" "$run_dir/final-replay" \
  "$replay_workers"
final_replay_finished=$(date +%s)

python3 - "$run_dir/ledger.sqlite3" "$run_dir/result.json" \
  "$target" "$scan_workers" "$started" "$scan_started" "$scan_finished" \
  "$wave_1_finished" "$wave_2_started" "$snapshot_started" \
  "$snapshot_replay_finished" "$final_replay_started" \
  "$final_replay_finished" "$runner_revision" "$runner_dirty" \
  "$writer_mode" <<'PY'
import hashlib
import json
import sqlite3
import sys
from pathlib import Path

ledger = Path(sys.argv[1])
output = Path(sys.argv[2])
target, workers, started, scan_started, scan_finished, wave_1_finished, \
    wave_2_started, snapshot_started, snapshot_finished, replay_started, \
    replay_finished = map(int, sys.argv[3:14])
runner_revision = sys.argv[14]
runner_dirty = int(sys.argv[15])
writer_mode = sys.argv[16]
database = sqlite3.connect(ledger)
counts = database.execute(
    "SELECT (SELECT COUNT(*) FROM blocks),"
    "(SELECT COUNT(*) FROM certificates),"
    "(SELECT COUNT(*) FROM vertices),"
    "(SELECT COUNT(*) FROM leases),"
    "(SELECT COUNT(*) FROM planned_work p LEFT JOIN blocks b USING(ordinal) "
    " WHERE b.ordinal IS NULL),"
    "(SELECT COUNT(*) FROM blocks b LEFT JOIN planned_work p USING(ordinal) "
    " WHERE p.ordinal IS NULL)"
).fetchone()
planned = database.execute(
    "SELECT shard_index,COUNT(*) FROM planned_work GROUP BY shard_index "
    "ORDER BY shard_index"
).fetchall()
actual = database.execute(
    "SELECT shard_index,COUNT(*) FROM blocks GROUP BY shard_index "
    "ORDER BY shard_index"
).fetchall()
statuses = dict(database.execute(
    "SELECT status,COUNT(*) FROM certificates GROUP BY status"
))
metadata = dict(database.execute(
    "SELECT key,value FROM meta WHERE key LIKE 'native_%' ORDER BY key"
))
quick = database.execute("PRAGMA quick_check").fetchone()[0]
foreign = database.execute("PRAGMA foreign_key_check").fetchall()
database.close()
if counts[0] != target or counts[3:] != (0, 0, 0) or planned != actual or \
        len(planned) != workers or quick != "ok" or foreign:
    raise SystemExit(
        f"invalid final ledger counts={counts} planned={planned} actual={actual} "
        f"quick={quick} foreign={len(foreign)}"
    )
digest = hashlib.sha256()
with ledger.open("rb") as stream:
    for chunk in iter(lambda: stream.read(1024 * 1024), b""):
        digest.update(chunk)
result = {
    "schema": "m23-native-mixed-wave-v1",
    "blocks": counts[0], "certificates": counts[1], "vertices": counts[2],
    "shards": planned, "statuses": statuses, "metadata": metadata,
    "database_sha256": digest.hexdigest(), "quick_check": "ok",
    "foreign_key_violations": 0, "snapshot_prefix_replay": True,
    "exact_final_replay": True,
    "runner_git_revision": runner_revision, "runner_git_dirty": runner_dirty,
    "writer_mode": writer_mode,
    "scan_seconds": ((wave_1_finished - scan_started) +
                     (scan_finished - wave_2_started)),
    "scan_wall_seconds": scan_finished - scan_started,
    "checkpoint_pause_seconds": wave_2_started - wave_1_finished,
    "snapshot_replay_seconds": snapshot_finished - snapshot_started,
    "scan_replay_overlap_seconds": max(
        0, min(scan_finished, snapshot_finished) - wave_2_started
    ),
    "final_replay_seconds": replay_finished - replay_started,
    "total_seconds": replay_finished - started,
}
output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
print(json.dumps(result, sort_keys=True))
PY

emit done "blocks=$target,scan_seconds=$((scan_finished - scan_started)),final_replay_seconds=$((final_replay_finished - final_replay_started))"
kill "$monitor_pid" "$sampler_pid" 2>/dev/null || true
wait "$monitor_pid" "$sampler_pid" 2>/dev/null || true
monitor_pid=0
sampler_pid=0
trap - EXIT INT TERM
