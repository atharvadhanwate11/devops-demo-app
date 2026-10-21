#!/usr/bin/env bash
# Stop the local Jenkins instance started by scripts/start_jenkins.sh
set -uo pipefail

PIDFILE="$HOME/jenkins/jenkins.pid"
if [ ! -f "$PIDFILE" ]; then
  echo "Jenkins is not running (no pid file)."
  exit 0
fi

PID="$(cat "$PIDFILE")"
if kill -0 "$PID" 2>/dev/null; then
  echo "Stopping Jenkins (PID $PID) ..."
  kill "$PID"
  for i in $(seq 1 20); do
    kill -0 "$PID" 2>/dev/null || break
    sleep 1
  done
  kill -9 "$PID" 2>/dev/null || true
fi
rm -f "$PIDFILE"
echo "Jenkins stopped."
