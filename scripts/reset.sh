#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Return the demo environment to a clean state WITHOUT touching the source
# code, the git history or the branches.
#
# Removed: demo containers, the Kubernetes deployment/service, the Jenkins
# process, the port-forward and the python virtual environment.
# Kept:     every file in the repository, all git commits and branches, the
#           docker images and the minikube cluster (use RESET_CLUSTER=1 to
#           delete that as well).
# ---------------------------------------------------------------------------
set -uo pipefail

export PATH="$HOME/bin:$PATH"
cd "$(dirname "$0")/.."

RESET_CLUSTER="${RESET_CLUSTER:-0}"

bold()  { printf '\033[1m%s\033[0m\n' "$*"; }
cyan()  { printf '\033[0;36m%s\033[0m\n' "$*"; }
green() { printf '\033[0;32m%s\033[0m\n' "$*"; }

bold "[1/7] Stopping the port-forward"
pkill -f "kubectl port-forward" 2>/dev/null && echo "  stopped" || echo "  nothing running"

bold "[2/7] Removing the demo containers"
for c in task-api-demo prometheus grafana; do
  if docker ps -a --format '{{.Names}}' | grep -qx "$c"; then
    docker rm -f "$c" >/dev/null 2>&1 && echo "  removed container: $c"
  else
    echo "  no container: $c"
  fi
done

bold "[3/7] Removing the Kubernetes deployment and service"
kubectl delete deployment task-api --ignore-not-found=true 2>/dev/null || true
kubectl delete service task-api --ignore-not-found=true 2>/dev/null || true
echo "  deployment and service deleted"

bold "[4/7] Restoring k8s/deployment.yaml to the committed version"
if ! git diff --quiet -- k8s/deployment.yaml; then
  git checkout -- k8s/deployment.yaml && echo "  restored from git"
else
  echo "  already identical to the committed version"
fi

bold "[5/7] Stopping Jenkins"
bash scripts/stop_jenkins.sh

bold "[6/7] Removing the local virtual environment"
rm -rf .venv .pytest_cache
find . -name "__pycache__" -type d -prune -exec rm -rf {} + 2>/dev/null || true
echo "  .venv removed"

bold "[7/7] Cluster"
if [ "$RESET_CLUSTER" = "1" ]; then
  echo "  deleting the minikube cluster (RESET_CLUSTER=1)"
  minikube delete || true
else
  echo "  minikube kept (set RESET_CLUSTER=1 to delete it)"
fi

echo
green "RESET COMPLETE. The repository, the git history and the branches are untouched."
git status --short
