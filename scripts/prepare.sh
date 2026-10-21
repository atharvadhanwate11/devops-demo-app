#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# One-time preparation before the demo:
#   * pull the container images so nothing is downloaded during the recording
#   * start minikube
#   * build the Docker image and load it into the cluster
#   * start Jenkins
#   * apply the Kubernetes manifests
#
# Safe to run more than once.
# ---------------------------------------------------------------------------
set -uo pipefail

export PATH="$HOME/bin:$PATH"
cd "$(dirname "$0")/.."

bold()  { printf '\033[1m%s\033[0m\n' "$*"; }
cyan()  { printf '\033[0;36m%s\033[0m\n' "$*"; }
green() { printf '\033[0;32m%s\033[0m\n' "$*"; }

bold "[1/6] Pre-pulling container images"
for img in python:3.11-slim prom/prometheus grafana/grafana; do
  if docker image inspect "$img" >/dev/null 2>&1; then
    green "  already present: $img"
  else
    echo "  pulling $img ..."
    docker pull -q "$img" || echo "  WARNING: could not pull $img"
  fi
done

bold "[2/6] Starting Minikube"
if minikube status >/dev/null 2>&1; then
  green "  minikube is already running"
else
  minikube start --driver=docker --cpus=2 --memory=4096
fi

bold "[3/6] Building the application image"
docker build -t task-api:1.0 .

bold "[4/6] Loading the image into Minikube"
minikube image load task-api:1.0

bold "[5/6] Applying the Kubernetes manifests"
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl rollout status deployment/task-api --timeout=180s
kubectl get pods -l app=task-api

bold "[6/6] Starting Jenkins"
bash scripts/start_jenkins.sh

echo
green "PREPARATION DONE. Everything is ready for the demo."
