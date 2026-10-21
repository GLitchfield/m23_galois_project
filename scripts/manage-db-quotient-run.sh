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
  echo "  $0 start PAIR_CHECKPOINT FIRST LAST START PROOF_LIMIT WALK_LIMIT RUN_DIR BLOCK_BUDGET" >&2
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
    [[ $# -eq 8 ]] || usage
    pair_checkpoint=$(realpath "$1")
    first=$2
    last=$3
    start=$4
    proof_limit=$5
    walk_limit=$6
    run_dir=$7
    block_budget=$8
    mkdir -p "$run_dir"
    run_dir=$(realpath "$run_dir")
    pid_file="$run_dir/runner.pid"
    if [[ -s "$pid_file" ]] && is_active "$(cat "$pid_file")"; then
      echo "run already active with pid $(cat "$pid_file")" >&2
      exit 1
    fi
    cd "$repo_root"
    nohup setsid "$repo_root/scripts/scan-direct-pair-quotient-db.sh" \
      "$pair_checkpoint" "$first" "$last" "$proof_limit" "$run_dir" \
      frontier "$start" "$block_budget" "$walk_limit" \
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
      echo "sent SIGINT to process group $pid; committed database transactions remain valid"
    else
      echo "managed process is not running"
    fi
    ;;
  *) usage ;;
esac
