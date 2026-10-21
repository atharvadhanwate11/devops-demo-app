#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Generate traffic against the Task Manager API so Prometheus and Grafana have
# something to show. A few invalid requests are included on purpose so that
# 4xx responses appear in the http_requests_total metric.
#
# Usage: bash scripts/traffic.sh [count] [delay_seconds] [base_url]
#   count  - number of request rounds           (default 30)
#   delay  - seconds between rounds              (default 1)
#   url    - base URL of the API                 (default http://localhost:8000)
# ---------------------------------------------------------------------------
set -uo pipefail

COUNT="${1:-30}"
DELAY="${2:-1}"
BASE_URL="${3:-http://localhost:8000}"

green() { printf '\033[0;32m%s\033[0m\n' "$*"; }
cyan()  { printf '\033[0;36m%s\033[0m\n' "$*"; }

cyan "Generating traffic: $COUNT rounds every ${DELAY}s against $BASE_URL"

ok=0; bad=0; created=0; deleted=0
for i in $(seq 1 "$COUNT"); do
  # 1) create a task
  code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/tasks" \
    -H 'Content-Type: application/json' \
    -d "{\"title\":\"demo task $i\"}")
  [ "$code" = "201" ] && created=$((created + 1)) || bad=$((bad + 1))

  # 2) list tasks
  code=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/tasks")
  [ "$code" = "200" ] && ok=$((ok + 1)) || bad=$((bad + 1))

  # 3) health check
  code=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/health")
  [ "$code" = "200" ] && ok=$((ok + 1)) || bad=$((bad + 1))

  # 4) invalid request on purpose -> produces a 400 in the metrics
  code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/tasks" \
    -H 'Content-Type: application/json' -d '{"name":"missing title"}')
  [ "$code" = "400" ] && ok=$((ok + 1)) || bad=$((bad + 1))

  # 5) invalid request on purpose -> produces a 422 in the metrics
  code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/tasks" \
    -H 'Content-Type: application/json' -d "{\"title\":\"$(printf 'x%.0s' $(seq 1 120))\"}")
  [ "$code" = "422" ] && ok=$((ok + 1)) || bad=$((bad + 1))

  # 6) delete the task we created (id == round number for a fresh store)
  code=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE "$BASE_URL/tasks/$i")
  [ "$code" = "200" ] && deleted=$((deleted + 1))

  printf "\r  round %s/%s  created=%s deleted=%s errors=%s" "$i" "$COUNT" "$created" "$deleted" "$bad"
  [ "$i" -lt "$COUNT" ] && sleep "$DELAY"
done

echo
green "Traffic finished: created=$created deleted=$deleted ok=$ok unexpected=$bad"
