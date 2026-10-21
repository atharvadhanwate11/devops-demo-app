# DEMO COMMANDS

Copy-paste ready commands for every section of the recorded demo.
Browser tabs are listed per section.

**Terminal:** WSL2 Ubuntu (`wsl` from PowerShell, then `cd ~/devops-demo-app`).
Everything below runs from `~/devops-demo-app`.

---

## One-time setup (do this BEFORE recording)

```bash
# 1. check the toolchain
bash scripts/setup_check.sh

# 2. start everything (pre-pull images, minikube, docker image, jenkins)
bash scripts/prepare.sh

# 3. make sure the app is reachable on port 8000
nohup kubectl port-forward --address 0.0.0.0 svc/task-api 8000:8000 > /tmp/pf.log 2>&1 &
curl -s http://localhost:8000/health
```

Expected: `setup_check.sh` prints `RESULT: ALL OK`, `prepare.sh` prints
`PREPARATION DONE`, `curl` prints `{"status":"ok"}`.

### Pre-recording checklist

- [ ] `bash scripts/setup_check.sh` -> ALL OK
- [ ] `bash scripts/prepare.sh` -> PREPARATION DONE
- [ ] `kubectl get pods -l app=task-api` -> 1/1 Running
- [ ] `curl -s http://localhost:8000/health` -> `{"status":"ok"}`
- [ ] `curl -s -u admin:admin http://localhost:8080/api/json` -> Jenkins JSON
- [ ] `curl -s http://localhost:9090/-/ready` -> `Prometheus Server is Ready.`
- [ ] `curl -s -u admin:admin http://localhost:3000/api/health` -> `"database": "ok"`
- [ ] Browser tabs open and reachable:
  - http://localhost:8000/health
  - http://localhost:8080
  - http://localhost:3000
  - http://localhost:9090/targets
  - https://github.com/atharvadhanwate11/devops-demo-app
- [ ] Screen recorder running, terminal font large enough to read
- [ ] `git status` clean, `git log --oneline -n 5` shows the expected history

---

## Section 1 - Git (Student 1)

```bash
git log --oneline --graph --all --decorate
git branch -a -vv
git remote -v
git shortlog -sn --all
git status
gh repo view --json name,visibility,url --jq '"repo=\(.name) url=\(.url)"'
git log --pretty=format:'%h %s' -n 8
gh pr list --state all --limit 10 --json number,title,state,headRefName,baseRefName \
  --jq '.[] | "PR #\(.number) [\(.state)] \(.headRefName) -> \(.baseRefName): \(.title)"'
bash scripts/git_conflict_demo.sh
```

Expected: the graph shows `develop`, `feature/*` branches and several
`Merge pull request` commits; the conflict demo prints `<<<<<<<`, `=======`,
`>>>>>>>` markers and finishes with `CONFLICT DEMO COMPLETE`.

**Browser tab:** https://github.com/atharvadhanwate11/devops-demo-app
(show the branches, the Pull requests tab, one merged PR).

---

## Section 2 - Jenkins (Student 2)

```bash
java -version
curl -s -u admin:admin http://localhost:8080/api/json | jq -r '.version' | xargs echo 'Jenkins version:'
cat Jenkinsfile
bash scripts/jenkins_setup.sh --trigger
kubectl get deployment task-api
kubectl get pods -l app=task-api
kubectl rollout history deployment/task-api
```

Expected: Jenkins prints `BUILD RESULT: SUCCESS (build #N)` and every stage is
green; `kubectl rollout history` shows the new revision.

**Browser tab:** http://localhost:8080 -> job `task-api-pipeline`
(show the green build, then "Pipeline Stages" / Console Output).

---

## Section 3 - Docker (Student 3)

```bash
docker --version
cat Dockerfile
docker build -t task-api:1.0 .
docker images task-api --format 'table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.ID}}'
docker run -d --name task-api-demo -p 8000:8000 task-api:1.0
docker ps --filter name=task-api-demo
curl -s http://localhost:8000/health; echo
curl -s -X POST http://localhost:8000/tasks -H 'Content-Type: application/json' -d '{"title":"ship the demo"}'; echo
curl -s -o /dev/null -w 'missing title  -> HTTP %{http_code}\n' -X POST http://localhost:8000/tasks \
  -H 'Content-Type: application/json' -d '{"name":"no title"}'
curl -s -o /dev/null -w 'title too long -> HTTP %{http_code}\n' -X POST http://localhost:8000/tasks \
  -H 'Content-Type: application/json' -d '{"title":"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"}'
docker inspect --format '{{.State.Health.Status}}' task-api-demo
docker logs --tail 10 task-api-demo
docker stop task-api-demo && docker rm task-api-demo
```

Expected: the build ends with `Successfully tagged task-api:1.0`, the image is
about 48 MB (197 MB virtual size), the health status is `healthy`, the two
validation calls return `HTTP 400` and `HTTP 422`.

**Browser tab:** http://localhost:8000/health (open it in a second tab so the
Docker section can show the same service running as a container).

---

## Section 4 - Kubernetes (Student 4)

```bash
minikube status
kubectl get nodes -o wide
docker images task-api --format 'table {{.Repository}}\t{{.Tag}}\t{{.Size}}'
minikube image load task-api:1.0
cat k8s/deployment.yaml
cat k8s/service.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl rollout status deployment/task-api --timeout=180s
kubectl get pods -l app=task-api -o wide
kubectl get svc task-api
kubectl scale deployment task-api --replicas=3
kubectl rollout status deployment/task-api --timeout=120s
kubectl get pods -l app=task-api
POD=$(kubectl get pods -l app=task-api -o jsonpath='{.items[0].metadata.name}'); kubectl delete pod $POD
sleep 10; kubectl get pods -l app=task-api
nohup kubectl port-forward --address 0.0.0.0 svc/task-api 8000:8000 > /tmp/pf.log 2>&1 &
sleep 5; curl -s http://localhost:8000/health; echo
```

Expected: `3/3 Running`, the deleted pod is replaced by a new one, and the
`curl` returns `{"status":"ok"}`.

**Browser tab:** http://localhost:8000/health

---

## Section 5 - Prometheus (all four)

```bash
docker rm -f prometheus 2>/dev/null
cat monitoring/prometheus.yml
docker run -d --name prometheus -p 9090:9090 --add-host=host.docker.internal:host-gateway \
  -v $(pwd)/monitoring/prometheus.yml:/etc/prometheus/prometheus.yml prom/prometheus
bash scripts/traffic.sh 15 1 http://localhost:8000
curl -s 'http://localhost:9090/api/v1/targets' | jq -r '.data.activeTargets[] | "\(.labels.job) status=\(.health) url=\(.scrapeUrl)"'
curl -s --data-urlencode 'query=sum(tasks_created_total)' http://localhost:9090/api/v1/query | jq -r '.data.result[0].value[1]'
curl -s --data-urlencode 'query=sum by (status) (rate(http_requests_total[1m]))' http://localhost:9090/api/v1/query | jq -r '.data.result[] | "status=\(.metric.status) rate=\(.value[1])"'
```

Expected: the target line shows `task-api status=up`, and the queries return
numbers (not `no data`).

**Browser tab:** http://localhost:9090/targets (green `task-api`) and the
**Graph** tab.

---

## Section 6 - Grafana (all four)

```bash
docker rm -f grafana 2>/dev/null
docker run -d --name grafana -p 3000:3000 --add-host=host.docker.internal:host-gateway \
  -v $(pwd)/monitoring/grafana/provisioning:/etc/grafana/provisioning \
  -v $(pwd)/monitoring/grafana/dashboards:/var/lib/grafana/dashboards grafana/grafana
sleep 15
curl -s -u admin:admin http://localhost:3000/api/health | jq -r '.database'
curl -s -u admin:admin http://localhost:3000/api/datasources | jq -r '.[] | "\(.name) uid=\(.uid) url=\(.url)"'
curl -s -u admin:admin 'http://localhost:3000/api/search?query=Task%20API' | jq -r '.[] | "\(.title) uid=\(.uid)"'
bash scripts/traffic.sh 20 1 http://localhost:8000
```

Expected: `database` is `ok`, the datasource is `Prometheus uid=prometheus`,
the dashboard `Task API - Overview` exists.

**Browser tab:** http://localhost:3000 (admin/admin) -> dashboards ->
`Task API - Overview`.

---

## Section 7 - Troubleshooting (all four)

```bash
# 1 baseline
kubectl get pods -l app=task-api
curl -s http://localhost:8000/health; echo

# 2 inject the fault
sed -i 's|image: task-api:1.0|image: task-api:invalid|' k8s/deployment.yaml
git diff k8s/deployment.yaml
kubectl apply -f k8s/deployment.yaml
sleep 20; kubectl get pods -l app=task-api
curl -s http://localhost:8000/health; echo          # old pods still serve

# 3 diagnose
BADPOD=$(kubectl get pods -l app=task-api -o jsonpath='{.items[?(@.status.phase=="Pending")].metadata.name}' | awk '{print $1}')
kubectl describe pod $BADPOD | tail -n 18
docker images task-api
docker image inspect task-api:invalid               # fails: no such image
git diff k8s/deployment.yaml
kubectl rollout history deployment/task-api
curl -s 'http://localhost:9090/api/v1/query?query=up%7Bjob%3D%22task-api%22%7D' | jq -r '.data.result[0].value[1]'

# 4 fix
sed -i 's|image: task-api:invalid|image: task-api:1.0|' k8s/deployment.yaml
kubectl apply -f k8s/deployment.yaml
kubectl rollout status deployment/task-api --timeout=180s
git diff --stat                                     # empty again

# 5 verify
kubectl get pods -l app=task-api
curl -s http://localhost:8000/health; echo
```

Expected: the broken pod shows `ErrImagePull` / `ImagePullBackOff`, the old
pods still answer HTTP 200, after the fix all pods are `Running` again and
`git diff --stat` prints nothing.

**Browser tab:** http://localhost:3000 (the "Service Status" panel stays green
during the outage - that is the point) and http://localhost:9090/targets.

---

## After the demo

```bash
bash scripts/reset.sh          # clean slate, keeps the code and the history
bash scripts/prepare.sh        # ready for a second run
```
