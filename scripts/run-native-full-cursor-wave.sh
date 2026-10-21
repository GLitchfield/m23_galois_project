#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 9 ]]; then
  echo "usage: $0 COORDINATES MASKS LEDGER RUN_DIR SCAN_WORKERS TARGET REPLAY_WORKERS PROOF WALK" >&2
  exit 2
fi

coordinates=$(realpath "$1")
masks=$(realpath "$2")
ledger=$(realpath "$3")
run_dir=$4
scan_workers=$5
target=$6
replay_workers=$7
proof=$8
walk=$9
for value in "$scan_workers" "$target" "$replay_workers" "$proof" "$walk"; do
  [[ "$value" =~ ^[1-9][0-9]*$ ]] || {
    echo "invalid positive native full-cursor wave value: $value" >&2
    exit 2
  }
done
(( walk >= proof )) || { echo "walk limit must cover proof limit" >&2; exit 2; }
[[ ! -e "$run_dir" ]] || {
  echo "refusing nonfresh native full-cursor wave directory: $run_dir" >&2
  exit 2
}
mkdir -p "$run_dir"
echo "$$" >"$run_dir/runner.pid"
progress="$run_dir/progress.tsv"
touch "$progress"

read -r current_blocks current_certificates macroblocks plan_shards plan_schema \
  < <(python3 - "$ledger" <<'PY'
import sqlite3,sys
c=sqlite3.connect("file:"+sys.argv[1]+"?mode=ro",uri=True)
m=dict(c.execute("SELECT key,value FROM meta"))
counts=c.execute("SELECT (SELECT COUNT(*) FROM blocks),"
                 "(SELECT COUNT(*) FROM certificates),"
                 "(SELECT COUNT(*) FROM leases)").fetchone()
c.close()
if counts[2]: raise SystemExit("native full-cursor ledger has live leases")
print(counts[0],counts[1],m.get("config_macroblock_count",0),
      m.get("native_work_plan_shards",0),
      m.get("native_work_plan_schema","missing"))
PY
)
[[ "$plan_schema" == m23-native-full-cursor-plan-v1 && \
   "$plan_shards" -eq "$scan_workers" && "$target" -gt "$current_blocks" && \
   "$target" -le "$macroblocks" ]] || {
  echo "native full-cursor wave differs from its frozen plan or boundary" >&2
  exit 2
}
revision=$(git rev-parse HEAD)
dirty=0
[[ -z "$(git status --short)" ]] || dirty=1
emit() {
  printf '%s\tnative-full-cursor\trun\tall\t%s\t%s\n' \
    "$(date +%s)" "$1" "$2" >>"$progress"
}
emit start "from=$current_blocks,target=$target,scan_workers=$scan_workers,replay_workers=$replay_workers,revision=$revision,dirty=$dirty"

scan_pid=0
prefix_pid=0
monitor_pid=0
sampler_pid=0
cleanup() {
  local status=$?
  trap - EXIT INT TERM
  for pid in "$scan_pid" "$prefix_pid" "$monitor_pid" "$sampler_pid"; do
    if (( pid > 0 )); then kill "$pid" 2>/dev/null || true; fi
  done
  for pid in "$scan_pid" "$prefix_pid" "$monitor_pid" "$sampler_pid"; do
    if (( pid > 0 )); then wait "$pid" 2>/dev/null || true; fi
  done
  if (( status != 0 )); then emit failed "exit=$status"; fi
  exit "$status"
}
trap cleanup EXIT INT TERM

python3 scripts/checkpoint_sqlite_ledger.py "$ledger" \
  >"$run_dir/checkpoint-prefix.json"
prefix_snapshot=""
prefix_started=0
if (( current_certificates > 0 )); then
  (( replay_workers <= current_certificates )) || {
    echo "more replay workers than prefix certificates" >&2
    exit 2
  }
  prefix_snapshot="$run_dir/prefix-$current_blocks.sqlite3"
  python3 scripts/snapshot_sqlite_ledger.py "$ledger" "$prefix_snapshot" \
    >"$run_dir/snapshot-prefix.json"
  prefix_started=$(date +%s)
  (
    ./scripts/run-native-sqlite-replay-workers.sh \
      "$coordinates" "$prefix_snapshot" "$run_dir/prefix-replay" \
      "$replay_workers"
    date +%s >"$run_dir/prefix-replay.finished"
  ) &
  prefix_pid=$!
fi

python3 scripts/monitor_native_sqlite_ledger.py "$ledger" "$target" \
  --interval 5 >"$run_dir/runner.log" &
monitor_pid=$!
python3 scripts/sample_process_trees.py "$run_dir/resources.tsv" \
  "$$" --labels wave --interval 5 &
sampler_pid=$!
scan_started=$(date +%s)
./scripts/run-native-sqlite-workers.sh \
  "$coordinates" "$masks" "$ledger" "$run_dir/scan" \
  "$scan_workers" "$target" "$proof" "$proof" "$walk" 60 &
scan_pid=$!
wait "$scan_pid"
scan_pid=0
scan_finished=$(date +%s)
prefix_finished=0
if (( prefix_pid > 0 )); then
  wait "$prefix_pid"
  prefix_pid=0
  prefix_finished=$(<"$run_dir/prefix-replay.finished")
fi
python3 scripts/checkpoint_sqlite_ledger.py "$ledger" \
  >"$run_dir/checkpoint-final.json"

final_started=$(date +%s)
./scripts/run-native-sqlite-replay-workers.sh \
  "$coordinates" "$ledger" "$run_dir/final-replay" "$replay_workers"
final_finished=$(date +%s)
audit_args=("$ledger")
if (( target == macroblocks )); then audit_args+=(--require-complete); fi
python3 scripts/audit_native_full_cursor_plan.py "${audit_args[@]}" \
  >"$run_dir/exhaustiveness-audit.json"

python3 - "$ledger" "$run_dir/result.json" "$current_blocks" "$target" \
  "$scan_workers" "$replay_workers" "$scan_started" "$scan_finished" \
  "$prefix_started" "$prefix_finished" "$final_started" "$final_finished" \
  "$revision" "$dirty" <<'PY'
import hashlib,json,sqlite3,sys
from pathlib import Path
ledger=Path(sys.argv[1]); output=Path(sys.argv[2])
old,target,scan_workers,replay_workers,scan_start,scan_finish,prefix_start,\
 prefix_finish,final_start,final_finish=map(int,sys.argv[3:13])
revision=sys.argv[13]; dirty=int(sys.argv[14])
c=sqlite3.connect(ledger)
counts=c.execute("SELECT (SELECT COUNT(*) FROM blocks),"
 "(SELECT COUNT(*) FROM certificates),(SELECT COUNT(*) FROM vertices),"
 "(SELECT COUNT(*) FROM leases),(SELECT COUNT(*) FROM planned_work)").fetchone()
statuses=dict(c.execute("SELECT status,COUNT(*) FROM certificates GROUP BY status"))
meta=dict(c.execute("SELECT key,value FROM meta WHERE key LIKE 'native_%'"))
quick=c.execute("PRAGMA quick_check").fetchone()[0]
foreign=c.execute("PRAGMA foreign_key_check").fetchall(); c.close()
if counts[0] != target or counts[3:] != (0,0) or quick != "ok" or foreign:
 raise SystemExit(f"invalid full-cursor wave counts={counts} quick={quick} foreign={len(foreign)}")
digest=hashlib.sha256()
with ledger.open("rb") as stream:
 for chunk in iter(lambda:stream.read(1024*1024),b""): digest.update(chunk)
result={
 "schema":"m23-native-full-cursor-wave-v1","from_blocks":old,
 "target_blocks":target,"added_blocks":target-old,"certificates":counts[1],
 "vertices":counts[2],"statuses":statuses,"metadata":meta,
 "scan_workers":scan_workers,"replay_workers":replay_workers,
 "scan_seconds":scan_finish-scan_start,
 "prefix_replay_seconds":0 if not prefix_start else prefix_finish-prefix_start,
 "scan_prefix_overlap_seconds":0 if not prefix_start else max(0,min(scan_finish,prefix_finish)-scan_start),
 "final_replay_seconds":final_finish-final_start,"database_sha256":digest.hexdigest(),
 "runner_git_revision":revision,"runner_git_dirty":dirty,"quick_check":"ok",
 "foreign_key_violations":0,"exact_final_replay":True,
 "exact_prefix_replay":bool(prefix_start),"materialized_plan_rows":counts[4],
}
output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
print(json.dumps(result,sort_keys=True))
PY
emit done "from=$current_blocks,target=$target,scan_seconds=$((scan_finished-scan_started)),final_replay_seconds=$((final_finished-final_started))"
kill "$monitor_pid" "$sampler_pid" 2>/dev/null || true
wait "$monitor_pid" "$sampler_pid" 2>/dev/null || true
monitor_pid=0
sampler_pid=0
trap - EXIT INT TERM
cat "$run_dir/result.json"
