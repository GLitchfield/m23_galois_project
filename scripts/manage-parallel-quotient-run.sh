#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

is_active() {
  local pid=$1 state
  kill -0 "$pid" 2>/dev/null || return 1
  state=$(ps -o stat= -p "$pid" 2>/dev/null || true)
  [[ -n "$state" && "$state" != Z* ]]
}

usage() {
  echo "usage:" >&2
  echo "  $0 start PAIR FIRST LAST START PROOF WALK RUN_DIR WORKERS VIRTUAL_SHARDS TARGET TRAVERSAL_ORDER" >&2
  echo "  $0 status RUN_DIR" >&2
  echo "  $0 wait RUN_DIR" >&2
  echo "  $0 stop RUN_DIR" >&2
  exit 2
}

[[ $# -ge 2 ]] || usage
command=$1
shift

case "$command" in
  start)
    [[ $# -eq 11 ]] || usage
    pair_checkpoint=$(realpath "$1")
    first=$2
    last=$3
    start=$4
    proof_limit=$5
    walk_limit=$6
    run_dir=$7
    workers=$8
    virtual_shards=$9
    shift 9
    target=$1
    traversal_order=$2
    for value in "$first" "$last" "$start" "$proof_limit" "$walk_limit" \
        "$workers" "$virtual_shards" "$target"; do
      [[ "$value" =~ ^[1-9][0-9]*$ ]] || {
        echo "invalid positive integer: $value" >&2
        exit 2
      }
    done
    [[ "$traversal_order" == legacy || "$traversal_order" == key-v1 || \
      "$traversal_order" == key-v2 ]] || {
      echo "invalid traversal order" >&2
      exit 2
    }
    [[ -s "$run_dir/ledger.sqlite3" && -s "$run_dir/shards.json" ]] || {
      echo "run directory must be prepared with m23_quotient_shards.py" >&2
      exit 2
    }
    run_dir=$(realpath "$run_dir")
    pid_file="$run_dir/runner.pid"
    if [[ -s "$pid_file" ]] && is_active "$(cat "$pid_file")"; then
      echo "run already active with pid $(cat "$pid_file")" >&2
      exit 1
    fi
    cd "$repo_root"
    nohup setsid env \
      M23_DETERMINISTIC_SHARDS=dynamic \
      M23_VIRTUAL_SHARDS="$virtual_shards" \
      M23_CACHE_RESET_INTERVAL="${M23_CACHE_RESET_INTERVAL:-500}" \
      M23_MIN_AVAILABLE_MIB="${M23_MIN_AVAILABLE_MIB:-12288}" \
      M23_PROFILE_INTERVAL="${M23_PROFILE_INTERVAL:-500}" \
      M23_PROGRESS_INTERVAL="${M23_PROGRESS_INTERVAL:-100}" \
      M23_TRAVERSAL_ORDER="$traversal_order" \
      "$repo_root/scripts/run-db-quotient-workers.sh" \
      "$pair_checkpoint" "$first" "$last" "$start" "$proof_limit" \
      "$walk_limit" "$run_dir" "$workers" "$target" \
      >"$run_dir/runner.log" 2>&1 &
    echo "$!" >"$pid_file"
    echo "started pid $!; inspect with: $0 status $run_dir"
    ;;
  status)
    [[ $# -eq 1 ]] || usage
    python3 "$repo_root/scripts/m23_run_status.py" "$1"
    ;;
  wait)
    [[ $# -eq 1 ]] || usage
    pid_file="$1/runner.pid"
    [[ -s "$pid_file" ]] || { echo "no managed pid file" >&2; exit 1; }
    pid=$(cat "$pid_file")
    while is_active "$pid"; do
      sleep 5
    done
    python3 "$repo_root/scripts/m23_run_status.py" "$1"
    ;;
  stop)
    [[ $# -eq 1 ]] || usage
    pid_file="$1/runner.pid"
    [[ -s "$pid_file" ]] || { echo "no managed pid file" >&2; exit 1; }
    pid=$(cat "$pid_file")
    if is_active "$pid"; then
      kill -INT -- "-$pid"
      echo "sent SIGINT to process group $pid; committed transactions remain valid"
    else
      echo "managed process is not running"
    fi
    ;;
  *) usage ;;
esac
