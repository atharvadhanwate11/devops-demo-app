#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Fully automated Jenkins setup (no clicking):
#   1. wait for Jenkins
#   2. create the pipeline job "task-api-pipeline" (Pipeline script from SCM)
#   3. trigger a build through the REST API and poll until it finishes
#   4. print the console output
#
# Usage: bash scripts/jenkins_setup.sh [--trigger] [--no-trigger]
# ---------------------------------------------------------------------------
set -uo pipefail

JENKINS_URL="${JENKINS_URL:-http://localhost:8080}"
JENKINS_USER="${JENKINS_USER:-admin}"
JENKINS_PASS="${JENKINS_PASS:-admin}"
JOB_NAME="${JOB_NAME:-task-api-pipeline}"
CJ="${JENKINS_COOKIES:-/tmp/jenkins_cookies.txt}"
REPO_URL="${REPO_URL:-https://github.com/atharvadhanwate11/devops-demo-app.git}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TRIGGER=1
for arg in "$@"; do
  case "$arg" in
    --no-trigger) TRIGGER=0 ;;
    --trigger)    TRIGGER=1 ;;
  esac
done

bold()  { printf '\033[1m%s\033[0m\n' "$*"; }
cyan()  { printf '\033[0;36m%s\033[0m\n' "$*"; }
green() { printf '\033[0;32m%s\033[0m\n' "$*"; }
red()   { printf '\033[0;31m%s\033[0m\n' "$*"; }

api() { # api <method> <path> [data-file]
  local method="$1" path="$2" data="${3:-}"
  local args=(-s -o /tmp/jenkins_api.out -w "%{http_code}" -c "$CJ" -b "$CJ" -u "$JENKINS_USER:$JENKINS_PASS" -X "$method")
  [ -n "$data" ] && args+=(-H "Content-Type: application/xml" --data-binary "@$data")
  curl "${args[@]}" "$JENKINS_URL$path"
}

bold "=============================================================="
bold " JENKINS AUTOMATED SETUP"
bold "=============================================================="

# ------------------------------------------------------------------ 1. wait
bold "[1/4] Waiting for Jenkins at $JENKINS_URL"
for i in $(seq 1 60); do
  if curl -fsS -c "$CJ" -b "$CJ" -u "$JENKINS_USER:$JENKINS_PASS" -o /dev/null "$JENKINS_URL/api/json"; then
    break
  fi
  printf "."
  sleep 2
done
echo
VERSION=$(curl -sI -c "$CJ" -b "$CJ" -u "$JENKINS_USER:$JENKINS_PASS" "$JENKINS_URL/api/json" \
  | awk -F': ' '/^[Xx]-Jenkins:/{print $2}' | tr -d '\r')
echo "  Jenkins version: ${VERSION:-unknown}"
if [ -z "$VERSION" ]; then
  red "ERROR: Jenkins API is not reachable with $JENKINS_USER/$JENKINS_PASS"
  exit 1
fi

# ------------------------------------------------------------------ 2. crumb
bold "[2/4] Getting the CSRF crumb"
CRUMB_JSON=$(curl -s -c "$CJ" -b "$CJ" -u "$JENKINS_USER:$JENKINS_PASS" "$JENKINS_URL/crumbIssuer/api/json")
CRUMB_FIELD=$(echo "$CRUMB_JSON" | jq -r '.crumbRequestField')
CRUMB_VALUE=$(echo "$CRUMB_JSON" | jq -r '.crumb')
echo "  crumb field: $CRUMB_FIELD"

# ------------------------------------------------------------------ 3. job
bold "[3/4] Creating pipeline job '$JOB_NAME' (Pipeline script from SCM)"
cat > /tmp/jenkins_job_config.xml <<EOF
<?xml version='1.1' encoding='UTF-8'?>
<flow-definition plugin="workflow-job">
  <description>Task API CI/CD pipeline - code to Git to Jenkins to Docker to Kubernetes</description>
  <keepDependencies>false</keepDependencies>
  <properties>
    <hudson.model.ParametersDefinitionProperty>
      <parameterDefinitions>
        <hudson.model.BooleanParameterDefinition>
          <name>PUSH_IMAGE</name>
          <description>Push the Docker image to Docker Hub (needs the dockerhub credentials)</description>
          <defaultValue>false</defaultValue>
        </hudson.model.BooleanParameterDefinition>
      </parameterDefinitions>
    </hudson.model.ParametersDefinitionProperty>
  </properties>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition" plugin="workflow-cps">
    <scm class="hudson.plugins.git.GitSCM" plugin="git">
      <configVersion>2</configVersion>
      <userRemoteConfigs>
        <hudson.plugins.git.UserRemoteConfig>
          <url>${REPO_URL}</url>
        </hudson.plugins.git.UserRemoteConfig>
      </userRemoteConfigs>
      <branches>
        <hudson.plugins.git.BranchSpec>
          <name>*/main</name>
        </hudson.plugins.git.BranchSpec>
      </branches>
      <doGenerateSubmoduleConfigurations>false</doGenerateSubmoduleConfigurations>
      <submoduleCfg class="list"/>
      <extensions/>
    </scm>
    <scriptPath>Jenkinsfile</scriptPath>
    <lightweight>false</lightweight>
  </definition>
  <triggers>
    <org.jenkinsci.plugins.workflow.cps.triggers.SCMTrigger>
      <spec>H/2 * * * *</spec>
    </org.jenkinsci.plugins.workflow.cps.triggers.SCMTrigger>
  </triggers>
  <disabled>false</disabled>
</flow-definition>
EOF

EXISTING=$(curl -s -c "$CJ" -b "$CJ" -u "$JENKINS_USER:$JENKINS_PASS" -o /dev/null -w "%{http_code}" "$JENKINS_URL/job/$JOB_NAME/api/json")
if [ "$EXISTING" = "200" ]; then
  echo "  job already exists - updating it"
  CODE=$(curl -s -c "$CJ" -b "$CJ" -u "$JENKINS_USER:$JENKINS_PASS" -o /tmp/jenkins_api.out -w "%{http_code}" \
    -X POST -H "$CRUMB_FIELD: $CRUMB_VALUE" -H "Content-Type: application/xml" \
    --data-binary @/tmp/jenkins_job_config.xml "$JENKINS_URL/job/$JOB_NAME/config.xml")
  echo "  update HTTP $CODE"
else
  CODE=$(curl -s -c "$CJ" -b "$CJ" -u "$JENKINS_USER:$JENKINS_PASS" -o /tmp/jenkins_api.out -w "%{http_code}" \
    -X POST -H "$CRUMB_FIELD: $CRUMB_VALUE" -H "Content-Type: application/xml" \
    --data-binary @/tmp/jenkins_job_config.xml "$JENKINS_URL/createItem?name=$JOB_NAME")
  echo "  create HTTP $CODE"
  if [ "$CODE" != "200" ] && [ "$CODE" != "201" ]; then
    red "ERROR creating job:"
    cat /tmp/jenkins_api.out
    exit 1
  fi
fi

# ------------------------------------------------------------------ 4. build
if [ "$TRIGGER" -eq 1 ]; then
  bold "[4/4] Triggering a build and waiting for the result"
  # Jenkins >= 2.5xx rejects a bare POST /build ("Nothing is submitted").
  # The form field "json" is what the Build Now button sends, and it works
  # for a job with parameters (PUSH_IMAGE stays false) and without.
  curl -s -c "$CJ" -b "$CJ" -u "$JENKINS_USER:$JENKINS_PASS" -o /dev/null -w "  trigger HTTP %{http_code}\n" \
    -X POST -H "$CRUMB_FIELD: $CRUMB_VALUE" \
    --data "json={}" "$JENKINS_URL/job/$JOB_NAME/build"

  BUILD_NO=""
  for i in $(seq 1 60); do
    BUILD_NO=$(curl -s -c "$CJ" -b "$CJ" -u "$JENKINS_USER:$JENKINS_PASS" \
      "$JENKINS_URL/job/$JOB_NAME/api/json?tree=builds%5Bnumber,result,building%5D" \
      | jq -r '.builds[0].number // empty')
    [ -n "$BUILD_NO" ] && break
    sleep 2
  done
  echo "  build number: $BUILD_NO"

  RESULT=""
  for i in $(seq 1 180); do
    RESULT=$(curl -s -c "$CJ" -b "$CJ" -u "$JENKINS_USER:$JENKINS_PASS" \
      "$JENKINS_URL/job/$JOB_NAME/$BUILD_NO/api/json?tree=result,building" \
      | jq -r '.result // (if .building then "RUNNING" else "UNKNOWN" end)')
    echo "    status: $RESULT"
    [ "$RESULT" != "RUNNING" ] && [ "$RESULT" != "UNKNOWN" ] && break
    sleep 5
  done

  echo
  bold "  console output (tail)"
  curl -s -c "$CJ" -b "$CJ" -u "$JENKINS_USER:$JENKINS_PASS" "$JENKINS_URL/job/$JOB_NAME/$BUILD_NO/consoleText" | tail -n 60

  echo
  if [ "$RESULT" = "SUCCESS" ]; then
    green "  BUILD RESULT: SUCCESS (build #${BUILD_NO})"
  else
    red "  BUILD RESULT: ${RESULT} (build #${BUILD_NO})"
    exit 1
  fi
else
  bold "[4/4] Build not triggered (--no-trigger)"
fi

echo
echo "Jenkins UI: ${JENKINS_URL}/job/${JOB_NAME}"
