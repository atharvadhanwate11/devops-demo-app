#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# DevOps Demo - presentation script
#
#   bash demo.sh                run every section in order
#   bash demo.sh git            run one section
#
# Sections: git | jenkins | docker | k8s | prom | grafana | trouble
#
# Environment options:
#   NOPAUSE=1     do not wait for ENTER between sections
#   DELAY=0       seconds to wait before each command (default 1)
#   NOCLEAR=1     do not clear the screen between sections
#   FRESH_BUILD=1 rebuild the Docker image with --no-cache
# ---------------------------------------------------------------------------
set -uo pipefail

export PATH="$HOME/bin:$PATH"
cd "$(dirname "$0")"

DELAY="${DELAY:-1}"
NOPAUSE="${NOPAUSE:-0}"
NOCLEAR="${NOCLEAR:-0}"
FRESH_BUILD="${FRESH_BUILD:-0}"
TRIGGER_BUILD="${TRIGGER_BUILD:-1}"

REPO_DIR="$PWD"
APP_URL="http://localhost:8000"
K8S_SERVICE="task-api"

# ------------------------------------------------------------------ colours
C_RESET=$'\033[0m'; C_RED=$'\033[0;31m'; C_GREEN=$'\033[0;32m'; C_YELLOW=$'\033[0;33m'
C_BLUE=$'\033[0;34m'; C_MAGENTA=$'\033[0;35m'; C_CYAN=$'\033[0;36m'; C_BOLD=$'\033[1m'

banner() {
  [ "$NOCLEAR" = "1" ] || clear
  printf '%s\n' "${C_BOLD}${C_MAGENTA}"
  printf '  %s\n' "############################################################"
  printf '  ##  %-58s ##\n' "$1"
  printf '  ##  %-58s ##\n' "$2"
  printf '  %s\n' "############################################################"
  printf '%s\n' "${C_RESET}"
}

explain() { printf '%s%s%s\n' "$C_CYAN" "$*" "$C_RESET"; }
browser() { printf '%s%s%s\n' "$C_YELLOW" ">>> $*" "$C_RESET"; }
note()    { printf '%s%s%s\n' "$C_GREEN" "$*" "$C_RESET"; }
warn()    { printf '%s%s%s\n' "$C_RED" "$*" "$C_RESET"; }

# run "<command>"  -> print the command, wait, then execute it
run() {
  printf '\n%s$ %s%s\n' "$C_GREEN" "$1" "$C_RESET"
  [ "$DELAY" != "0" ] && sleep "$DELAY"
  eval "$1"
}

pause() {
  [ "$NOPAUSE" = "1" ] && return 0
  printf '\n%sPress ENTER for the next section...%s' "$C_YELLOW" "$C_RESET"
  read -r _ || true
}

# ensure_app: make sure something answers on localhost:8000
ensure_app() {
  if curl -sf "$APP_URL/health" >/dev/null 2>&1; then
    return 0
  fi
  explain "Nothing is answering on localhost:8000 - starting a kubectl port-forward."
  if kubectl get svc "$K8S_SERVICE" >/dev/null 2>&1; then
    pkill -f "kubectl port-forward" 2>/dev/null || true
    nohup kubectl port-forward --address 0.0.0.0 "svc/$K8S_SERVICE" 8000:8000 \
      > /tmp/port-forward.log 2>&1 &
    echo $! > /tmp/port-forward.pid
    for i in $(seq 1 20); do
      curl -sf "$APP_URL/health" >/dev/null 2>&1 && break
      sleep 1
    done
  fi
  if curl -sf "$APP_URL/health" >/dev/null 2>&1; then
    note "The application is reachable on $APP_URL"
  else
    warn "Could not reach $APP_URL - run 'bash scripts/prepare.sh' first."
  fi
}

# =========================================================================
# SECTION 1 - GIT (Student 1)
# =========================================================================
section_git() {
  banner "SECTION 1 - SOURCE CONTROL" "Student 1: Git, branching, pull requests and conflicts"
  explain "This is where the code lives. Every change starts here."

  run "git --version"
  run "git log --oneline --graph --all --decorate"
  run "git branch -a -vv"
  run "git remote -v"
  run "git shortlog -sn --all"
  run "git status"
  run "gh repo view --json name,visibility,url --jq '\"repo=\\(.name) visibility=\\(.visibility) url=\\(.url)\"'"

  explain "Every commit follows Conventional Commits: feat:, fix:, ci:, docs:, chore:."
  run "git log --pretty=format:'%h %s' -n 8"

  browser "SWITCH TO THE BROWSER - open https://github.com/atharvadhanwate11/devops-demo-app"
  explain "Show the repository: branches, pull requests tab, and the merge commits."
  run "gh pr list --state all --limit 10 --json number,title,state,headRefName,baseRefName --jq '.[] | \"PR #\\(.number) [\\(.state)] \\(.headRefName) -> \\(.baseRefName): \\(.title)\"'"

  explain "Now a real merge conflict, in a throw-away clone. The real repo is untouched."
  run "bash scripts/git_conflict_demo.sh"
  pause
}

# =========================================================================
# SECTION 2 - JENKINS (Student 2)
# =========================================================================
section_jenkins() {
  banner "SECTION 2 - CONTINUOUS INTEGRATION / DELIVERY" "Student 2: Jenkins pipeline: checkout, test, build, deploy"
  explain "Jenkins is the automation server. It watches Git and runs the pipeline."
  run "java -version"
  run "curl -s -u admin:admin http://localhost:8080/api/json | jq -r '.version' | xargs echo 'Jenkins version:'"

  explain "The pipeline is described in the Jenkinsfile that lives in Git."
  run "cat Jenkinsfile"

  browser "SWITCH TO THE BROWSER - open http://localhost:8080 (admin/admin) and the task-api-pipeline job"
  explain "The job was created automatically from the public GitHub repo - no clicking required."

  if [ "$TRIGGER_BUILD" = "1" ]; then
    explain "Triggering a build through the Jenkins REST API and waiting for the result."
    run "bash scripts/jenkins_setup.sh --trigger"
  else
    explain "TRIGGER_BUILD=0 - the build was triggered manually in the browser."
  fi

  explain "The pipeline did all of this automatically:"
  run "kubectl get deployment task-api"
  run "kubectl get pods -l app=task-api"
  run "kubectl rollout history deployment/task-api"
  pause
}

# =========================================================================
# SECTION 3 - DOCKER (Student 3)
# =========================================================================
section_docker() {
  banner "SECTION 3 - CONTAINERISATION" "Student 3: Docker image, container, validation and logs"
  explain "Docker packages the app and its dependencies into one reproducible image."

  run "docker --version"
  run "cat Dockerfile"

  explain "Building the image. The requirements are copied first so the layer is cached."
  if [ "$FRESH_BUILD" = "1" ]; then
    run "docker build --no-cache -t task-api:1.0 ."
  else
    run "docker build -t task-api:1.0 ."
  fi
  run "docker images task-api --format 'table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.ID}}'"
  run "docker history task-api:1.0 | head -n 5"

  explain "Running the image as a container on port 8000."
  run "docker rm -f task-api-demo 2>/dev/null || true"
  run "docker run -d --name task-api-demo -p 8000:8000 task-api:1.0"
  run "docker ps --filter name=task-api-demo --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"

  explain "Talking to the API."
  run "curl -s $APP_URL/health; echo"
  run "curl -s -X POST $APP_URL/tasks -H 'Content-Type: application/json' -d '{\"title\":\"ship the demo\"}'; echo"
  run "curl -s $APP_URL/tasks; echo"

  explain "Validation: a missing title gives 400, a title that is too long gives 422."
  run "curl -s -o /dev/null -w 'missing title  -> HTTP %{http_code}\\n' -X POST $APP_URL/tasks -H 'Content-Type: application/json' -d '{\"name\":\"no title\"}'"
  run "curl -s -o /dev/null -w 'title too long -> HTTP %{http_code}\\n' -X POST $APP_URL/tasks -H 'Content-Type: application/json' -d \"{\\\"title\\\":\\\"\$(printf 'x%.0s' \$(seq 1 120))\\\"}\""

  explain "The container has its own healthcheck and its own logs."
  run "docker inspect --format '{{.State.Health.Status}}' task-api-demo"
  run "docker logs --tail 10 task-api-demo"

  run "docker stop task-api-demo && docker rm task-api-demo"
  note "Container stopped and removed. The image stays on the machine."
  pause
}

# =========================================================================
# SECTION 4 - KUBERNETES (Student 4)
# =========================================================================
section_k8s() {
  banner "SECTION 4 - ORCHESTRATION" "Student 4: Minikube, Deployment, Service, scaling and self-healing"
  explain "Kubernetes runs the container image and keeps it alive."

  run "minikube version"
  run "minikube status"
  run "kubectl version --client"

  explain "Minikube is a single node Kubernetes cluster running locally."
  run "minikube start --driver=docker"
  run "kubectl get nodes -o wide"

  explain "Loading the image we built with Docker into the cluster."
  run "docker images task-api --format 'table {{.Repository}}\t{{.Tag}}\t{{.Size}}'"
  run "minikube image load task-api:1.0"

  explain "The Deployment describes the pods, the Service gives them a stable address."
  run "cat k8s/deployment.yaml"
  run "cat k8s/service.yaml"

  run "kubectl apply -f k8s/deployment.yaml"
  run "kubectl apply -f k8s/service.yaml"
  run "kubectl rollout status deployment/task-api --timeout=180s"
  run "kubectl get pods -l app=task-api -o wide"
  run "kubectl get svc task-api"

  explain "Scaling to three replicas - the Service load balances over all of them."
  run "kubectl scale deployment task-api --replicas=3"
  run "kubectl rollout status deployment/task-api --timeout=120s"
  run "kubectl get pods -l app=task-api"

  explain "Self healing: delete one pod and Kubernetes creates a new one."
  run "POD=\$(kubectl get pods -l app=task-api -o jsonpath='{.items[0].metadata.name}'); echo killing \$POD; kubectl delete pod \$POD"
  run "sleep 10; kubectl get pods -l app=task-api"

  explain "Reaching the service from this machine through a port-forward."
  run "pkill -f 'kubectl port-forward' 2>/dev/null || true"
  run "nohup kubectl port-forward --address 0.0.0.0 svc/task-api 8000:8000 > /tmp/port-forward.log 2>&1 & sleep 5"
  run "curl -s $APP_URL/health; echo"
  run "curl -s $APP_URL/metrics | grep -E '^(tasks_created_total|tasks_current)' "

  browser "SWITCH TO THE BROWSER - open http://localhost:8000/health in a new tab"
  pause
}

# =========================================================================
# SECTION 5 - PROMETHEUS (all four)
# =========================================================================
section_prom() {
  banner "SECTION 5 - MONITORING" "Prometheus: scraping the application every 5 seconds"
  ensure_app
  explain "Prometheus pulls metrics from the application. It does not push."

  run "docker rm -f prometheus 2>/dev/null || true"
  run "cat monitoring/prometheus.yml"
  run "docker run -d --name prometheus -p 9090:9090 --add-host=host.docker.internal:host-gateway -v \$(pwd)/monitoring/prometheus.yml:/etc/prometheus/prometheus.yml prom/prometheus"

  explain "Generating traffic so there is something to scrape."
  run "bash scripts/traffic.sh 15 1 $APP_URL"

  explain "Is the target up?"
  run "curl -s 'http://localhost:9090/api/v1/targets' | jq -r '.data.activeTargets[] | \"\\(.labels.job)  status=\\(.health)  url=\\(.scrapeUrl)\"'"

  explain "How many tasks were created?"
  run "curl -s --data-urlencode 'query=sum(tasks_created_total)' http://localhost:9090/api/v1/query | jq -r '.data.result[0].value[1] // \"no data\"' | xargs echo 'tasks_created_total ='"

  explain "Live request rate per status code:"
  run "curl -s --data-urlencode 'query=sum by (status) (rate(http_requests_total[1m]))' http://localhost:9090/api/v1/query | jq -r '.data.result[] | \"status=\\(.metric.status)  rate=\\(.value[1])\"'"

  browser "SWITCH TO THE BROWSER - open http://localhost:9090/targets and the Graph tab"
  pause
}

# =========================================================================
# SECTION 6 - GRAFANA (all four)
# =========================================================================
section_grafana() {
  banner "SECTION 6 - VISUALISATION" "Grafana: the provisioned dashboard with live data"
  ensure_app
  explain "Grafana turns Prometheus metrics into a dashboard."

  run "docker rm -f grafana 2>/dev/null || true"
  run "docker run -d --name grafana -p 3000:3000 --add-host=host.docker.internal:host-gateway -v \$(pwd)/monitoring/grafana/provisioning:/etc/grafana/provisioning -v \$(pwd)/monitoring/grafana/dashboards:/var/lib/grafana/dashboards grafana/grafana"

  explain "Waiting for Grafana and the data source to be provisioned."
  run "sleep 15; curl -s -u admin:admin http://localhost:3000/api/health | jq -r '.database // .version'"

  explain "Data source (provisioned from a file, no manual clicks):"
  run "curl -s -u admin:admin http://localhost:3000/api/datasources | jq -r '.[] | \"\\(.name)  uid=\\(.uid)  type=\\(.type)  url=\\(.url)\"'"

  explain "Dashboard:"
  run "curl -s -u admin:admin 'http://localhost:3000/api/search?query=Task%20API' | jq -r '.[] | \"\\(.title)  uid=\\(.uid)  url=\\(if .url then .url else \"\" end)\"'"

  explain "Keeping traffic flowing so the panels have live data."
  run "bash scripts/traffic.sh 20 1 $APP_URL"

  explain "Querying Prometheus through Grafana (panel 2: tasks created per second):"
  run "DSUID=\$(curl -s -u admin:admin http://localhost:3000/api/datasources | jq -r '.[0].uid'); curl -s -u admin:admin -H 'Content-Type: application/json' -X POST http://localhost:3000/api/ds/query -d \"{\\\"queries\\\":[{\\\"refId\\\":\\\"A\\\",\\\"datasource\\\":{\\\"uid\\\":\\\"\\\$DSUID\\\"},\\\"expr\\\":\\\"rate(tasks_created_total[1m])\\\"}],\\\"from\\\":\\\"now-5m\\\",\\\"to\\\":\\\"now\\\"}\" | jq -r '.results.A.frames[0].data.values[0][0] // \"no data\"' | xargs echo 'latest tasks/s ='"

  browser "SWITCH TO THE BROWSER - open http://localhost:3000 (admin/admin) -> Task API - Overview"
  pause
}

# =========================================================================
# SECTION 7 - TROUBLESHOOTING (all four)
# =========================================================================
section_trouble() {
  banner "SECTION 7 - TROUBLESHOOTING" "A broken image tag: how four tools find the root cause"
  explain "Everything works. Now we break it on purpose and fix it."

  note "STEP 1 - baseline: the system is healthy."
  run "kubectl get pods -l app=task-api"
  run "curl -s $APP_URL/health; echo"

  note "STEP 2 - inject the fault: the image tag does not exist."
  run "sed -i 's|image: task-api:1.0|image: task-api:invalid|' k8s/deployment.yaml"
  run "git diff k8s/deployment.yaml"
  run "kubectl apply -f k8s/deployment.yaml"
  explain "Waiting for the new pod to fail its image pull..."
  run "sleep 20; kubectl get pods -l app=task-api"

  explain "The OLD pods still serve traffic - a rolling update protects the service."
  run "kubectl get pods -l app=task-api --field-selector=status.phase=Running"
  run "curl -s $APP_URL/health; echo"

  note "STEP 3 - diagnose with four different tools."
  explain "Tool 1 - Kubernetes: describe the broken pod and read the events."
  run "BADPOD=\$(kubectl get pods -l app=task-api -o jsonpath='{.items[?(@.status.phase==\"Pending\")].metadata.name}' | awk '{print \$1}'); echo bad pod: \$BADPOD; kubectl describe pod \$BADPOD | tail -n 18"

  explain "Tool 2 - Docker: the image simply is not there."
  run "docker images task-api --format 'table {{.Repository}}\t{{.Tag}}\t{{.Size}}'"
  run "docker image inspect task-api:invalid"

  explain "Tool 3 - Git: what exactly did we change?"
  run "git diff k8s/deployment.yaml"
  run "git log --oneline -n 3 -- k8s/deployment.yaml"

  explain "Tool 4 - Jenkins: the next pipeline run would fail here."
  run "kubectl rollout history deployment/task-api"

  explain "Tool 5 - Grafana: the service stayed UP, so the dashboard stayed green."
  run "curl -s 'http://localhost:9090/api/v1/query?query=up%7Bjob%3D%22task-api%22%7D' | jq -r '.data.result[0].value[1] // \"no data\"' | xargs echo 'up ='"

  note "STEP 4 - fix: put the correct tag back."
  run "sed -i 's|image: task-api:invalid|image: task-api:1.0|' k8s/deployment.yaml"
  run "kubectl apply -f k8s/deployment.yaml"
  run "kubectl rollout status deployment/task-api --timeout=180s"
  run "git diff --stat"
  note "git diff --stat is empty again - the file matches the committed version."
  explain "The alternative would have been: kubectl rollout undo deployment/task-api"

  note "STEP 5 - verify the recovery."
  run "kubectl get pods -l app=task-api"
  run "curl -s $APP_URL/health; echo"
  run "curl -s $APP_URL/tasks; echo"
  pause
}

# =========================================================================
# runner
# =========================================================================
ALL_SECTIONS="git jenkins docker k8s prom grafana trouble"

usage() {
  echo "Usage: bash demo.sh [section]"
  echo "Sections: $ALL_SECTIONS"
  echo "Options : NOPAUSE=1 DELAY=0 NOCLEAR=1 FRESH_BUILD=1"
}

if [ $# -eq 0 ]; then
  SECTIONS="$ALL_SECTIONS"
else
  case "$1" in
    git)     SECTIONS="git" ;;
    jenkins) SECTIONS="jenkins" ;;
    docker)  SECTIONS="docker" ;;
    k8s|kubernetes) SECTIONS="k8s" ;;
    prom|prometheus) SECTIONS="prom" ;;
    grafana) SECTIONS="grafana" ;;
    trouble|troubleshooting) SECTIONS="trouble" ;;
    -h|--help|help) usage; exit 0 ;;
    *) echo "Unknown section: $1"; usage; exit 1 ;;
  esac
fi

for s in $SECTIONS; do
  case "$s" in
    git)     section_git ;;
    jenkins) section_jenkins ;;
    docker)  section_docker ;;
    k8s)     section_k8s ;;
    prom)    section_prom ;;
    grafana) section_grafana ;;
    trouble) section_trouble ;;
  esac
done

echo
note "DEMO FINISHED - source code -> Git -> Jenkins -> Docker -> Kubernetes -> Prometheus -> Grafana"
