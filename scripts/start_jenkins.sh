#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Start Jenkins as the current user (so the pipeline can use docker, kubectl and
# minikube directly). Downloads jenkins.war + plugins on first run and creates
# the local admin user (admin/admin) with a Groovy init script.
#
# Usage: bash scripts/start_jenkins.sh
# ---------------------------------------------------------------------------
set -uo pipefail

export PATH="$HOME/bin:$PATH"

JENKINS_DIR="$HOME/jenkins"
WAR="$JENKINS_DIR/jenkins.war"
JENKINS_HOME="$JENKINS_DIR/home"
LOG="$JENKINS_DIR/jenkins.log"
PIDFILE="$JENKINS_DIR/jenkins.pid"
PORT="${JENKINS_PORT:-8080}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Pinned versions (stable and Java 17 compatible).
JENKINS_VERSION="${JENKINS_VERSION:-2.580.1}"
PLUGIN_MANAGER_VERSION="${PLUGIN_MANAGER_VERSION:-2.15.0}"
PLUGIN_MANAGER_JAR="$JENKINS_DIR/jenkins-plugin-manager.jar"

mkdir -p "$JENKINS_HOME"

# ---------------------------------------------------------------- already up?
if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
  echo "Jenkins is already running (PID $(cat "$PIDFILE")) on http://localhost:$PORT"
  exit 0
fi

# ------------------------------------------------------------ download war?
if [ ! -f "$WAR" ]; then
  echo "Downloading jenkins.war $JENKINS_VERSION ..."
  curl -fsSL -o "$WAR" "https://get.jenkins.io/war-stable/$JENKINS_VERSION/jenkins.war" || {
    echo "ERROR: could not download jenkins.war" >&2
    exit 1
  }
  echo "Saved to $WAR ($(du -h "$WAR" | cut -f1))"
fi

# ------------------------------------------- admin user (groovy init script)
mkdir -p "$JENKINS_HOME/init.groovy.d"
cp "$SCRIPT_DIR/jenkins/01-admin-user.groovy" "$JENKINS_HOME/init.groovy.d/01-admin-user.groovy"

# ------------------------------------------------------------ install plugins
if [ ! -f "$PLUGIN_MANAGER_JAR" ]; then
  echo "Downloading jenkins-plugin-manager $PLUGIN_MANAGER_VERSION ..."
  curl -fsSL -o "$PLUGIN_MANAGER_JAR" \
    "https://github.com/jenkinsci/plugin-installation-manager-tool/releases/download/$PLUGIN_MANAGER_VERSION/jenkins-plugin-manager-$PLUGIN_MANAGER_VERSION.jar" || {
      echo "ERROR: could not download jenkins-plugin-manager" >&2
      exit 1
    }
fi

echo "Installing Jenkins plugins (only if missing) ..."
JENKINS_HOME="$JENKINS_HOME" java -jar "$PLUGIN_MANAGER_JAR" \
  --war "$WAR" \
  --plugin-file "$SCRIPT_DIR/jenkins/plugins.txt" \
  --plugin-download-directory "$JENKINS_HOME/plugins" \
  --verbose 2>&1 | tail -n 5

# ------------------------------------------------------------- start it
echo "Starting Jenkins on port $PORT (log: $LOG) ..."
JENKINS_HOME="$JENKINS_HOME" PATH="$PATH" HOME="$HOME" nohup java \
  -Djenkins.install.runSetupWizard=false \
  -Djava.awt.headless=true \
  -Djenkins.model.Jenkins.slaveAgentPort=-1 \
  -jar "$WAR" --httpPort="$PORT" --httpListenAddress=0.0.0.0 \
  > "$LOG" 2>&1 &

echo $! > "$PIDFILE"
echo "PID $(cat "$PIDFILE") written to $PIDFILE"

printf "Waiting for Jenkins"
for i in $(seq 1 90); do
  if curl -fsS -o /dev/null "http://localhost:$PORT/login" 2>/dev/null; then
    echo
    echo "Jenkins is up: http://localhost:$PORT  (admin/admin)"
    exit 0
  fi
  printf "."
  sleep 2
done

echo
echo "ERROR: Jenkins did not come up in time. Last log lines:" >&2
tail -n 30 "$LOG" >&2
exit 1
