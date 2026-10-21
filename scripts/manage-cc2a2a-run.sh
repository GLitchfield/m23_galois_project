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
  echo "  $0 start CLASS_ORDER SHARD_COUNT RUN_DIR [JOBS]" >&2
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
    [[ $# -ge 3 && $# -le 4 ]] || usage
    class_order=$1
    shard_count=$2
    run_dir=$3
    jobs=${4:-4}
    mkdir -p "$run_dir"
    run_dir=$(cd "$run_dir" && pwd)
    pid_file="$run_dir/runner.pid"
    if [[ -s "$pid_file" ]] && is_active "$(cat "$pid_file")"; then
      echo "run already active with pid $(cat "$pid_file")" >&2
      exit 1
    fi
    result="$run_dir/published-result.tsv"
    certificate="$run_dir/published-certificate.tsv"
    cd "$repo_root"
    nohup setsid env M23_JOBS="$jobs" "$repo_root/scripts/run-sharded-cc2a2a.sh" \
      "$class_order" "$shard_count" "$run_dir" "$result" "$certificate" \
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
      echo "sent SIGINT to process group $pid; atomic checkpoints are preserved"
    else
      echo "managed process is not running"
    fi
    ;;
  *) usage ;;
esac
