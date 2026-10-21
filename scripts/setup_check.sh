#!/usr/bin/env bash
# Phase 0 - Preflight: verify every tool in the DevOps toolchain is installed and working.
# Usage: bash scripts/setup_check.sh
# Exit code 0 = all OK, 1 = one or more problems found.
set -uo pipefail

export PATH="$HOME/bin:$PATH"

OK_COUNT=0
FAIL_COUNT=0

green() { printf '\033[0;32m%s\033[0m\n' "$*"; }
red()   { printf '\033[0;31m%s\033[0m\n' "$*"; }
bold()  { printf '\033[1m%s\033[0m\n' "$*"; }

check() {
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then
    green "  [OK]   $name"
    OK_COUNT=$((OK_COUNT + 1))
  else
    red   "  [FAIL] $name"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

bold "=============================================="
bold " DevOps Demo - Preflight / Setup Check"
bold "=============================================="

bold "[1/3] Command line tools"
check "git"                 git --version
check "gh (GitHub CLI)"     gh --version
check "python3"             python3 --version
check "pip3"                python3 -m pip --version
check "curl"                curl --version
check "docker"              docker --version
check "kubectl"             kubectl version --client=true
check "minikube"            minikube version
check "java (Jenkins needs 17+)" java -version
check "jq"                  jq --help
check "unzip"               unzip -v

bold "[2/3] Services and runtimes"
check "docker daemon reachable"  docker ps
check "python3 venv module"      python3 -c "import venv"
check "docker compose (plugin)"  docker compose version
check "pipx/pip install possible" python3 -m pip --version

bold "[3/3] Optional components (informational)"
if docker ps >/dev/null 2>&1; then
  echo "  docker server: $(docker info --format '{{.ServerVersion}}' 2>/dev/null) (storage: $(docker info --format '{{.Driver}}' 2>/dev/null))"
else
  echo "  docker server: NOT RUNNING"
fi
if [ -f "$HOME/.kube/config" ]; then
  echo "  kubeconfig    : $HOME/.kube/config (minikube cluster present)"
else
  echo "  kubeconfig    : not created yet (run: minikube start --driver=docker)"
fi
if [ -f "$HOME/jenkins/jenkins.war" ]; then
  echo "  jenkins.war   : $HOME/jenkins/jenkins.war"
else
  echo "  jenkins.war   : not downloaded yet (run: bash scripts/start_jenkins.sh)"
fi

echo
if [ "$FAIL_COUNT" -eq 0 ]; then
  green "RESULT: ALL OK ($OK_COUNT checks passed, 0 failed)"
  exit 0
fi
red "RESULT: $FAIL_COUNT PROBLEM(S) FOUND ($OK_COUNT passed, $FAIL_COUNT failed)"
exit 1
