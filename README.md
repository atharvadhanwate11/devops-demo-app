# DevOps Demo App - Task Manager API

A complete, working DevOps toolchain in one small repository:

```
code -> Git/GitHub -> Jenkins CI/CD -> Docker -> Kubernetes (Minikube)
     -> Prometheus -> Grafana -> troubleshooting scenario
```

The application is deliberately tiny and boring (a Flask REST API with an
in-memory store) so that the pipeline is fast and nothing about the app can
break the demo.

---

## 1. The application

| Endpoint                | Method | Result |
|-------------------------|--------|--------|
| `/health`               | GET    | `{"status":"ok"}` |
| `/health/details`       | GET    | service name, version and task count |
| `/tasks`                | GET    | `{"tasks":[...],"count":n}` |
| `/tasks`                | POST   | create a task from `{"title":"..."}` - **201** |
| `/tasks/<id>`           | DELETE | delete a task - **200**, or **404** if unknown |
| `/metrics`              | GET    | Prometheus metrics |

Validation rules for `POST /tasks`:

* `title` missing or not a string -> **400 Bad Request**
* `title` empty -> **400 Bad Request**
* `title` longer than 100 characters (`MAX_TITLE_LENGTH`) -> **422 Unprocessable Entity**

Prometheus metrics exposed on `/metrics`:

| Metric | Type | Meaning |
|--------|------|---------|
| `tasks_created_total` | Counter | tasks created since start |
| `tasks_deleted_total` | Counter | tasks deleted since start |
| `request_latency_seconds` | Histogram | request latency in seconds |
| `http_requests_total{method,path,status}` | Counter | every HTTP request |
| `tasks_current` | Gauge | tasks currently in memory |

---

## 2. Architecture

```
                    +----------------------+
                    |   Developer laptop   |
                    |   (WSL2 Ubuntu)      |
                    +----------+-----------+
                               |
                    git push / pull request
                               v
                    +----------------------+
                    |      GitHub          |   main + develop + feature branches
                    |  atharvadhanwate11/  |   pull requests, merge commits
                    |  devops-demo-app     |
                    +----------+-----------+
                               |
                    pollSCM('H/2 * * * *') + webhook / manual trigger
                               v
                    +----------------------+
                    |       Jenkins        |   jenkins.war on :8080
                    |  task-api-pipeline   |   Pipeline script from SCM (Jenkinsfile)
                    +----------+-----------+
                               |
          +--------------------+--------------------+
          |                    |                    |
   Install & Test        Build Docker        Load image into
   (venv + pytest)       Image               Minikube + kubectl apply
          |                    |                    |
          v                    v                    v
   +-------------+      +-------------+      +------------------+
   |   pytest    |      |   Docker    |      |   Kubernetes     |
   |  13 tests   |      | task-api:1.0|      |  Deployment      |
   +-------------+      +------+------+      |  3 pods, probes  |
                              |             |  Service NodePort|
                              +------------>|  :30000          |
                                            +--------+---------+
                                                     |
                            +------------------------+------------------------+
                            |                                                 |
                    +-------v--------+                               +--------v--------+
                    |   Prometheus    |  scrape every 5s                |    Grafana     |
                    |   :9090         |  host.docker.internal:8000     |    :3000       |
                    +-------+--------+                               +--------+--------+
                            |                                                 |
                            +--------------------+----------------------------+
                                                 |
                                    +------------v-------------+
                                    |   Task Manager API      |
                                    |   :8000 /health /tasks   |
                                    |   /metrics               |
                                    +--------------------------+
```

---

## 3. Repository layout

```
devops-demo-app/
├── app/                     Flask application
│   ├── app.py               routes, validation, metrics hook
│   ├── config.py            MAX_TITLE_LENGTH and friends
│   ├── metrics.py           Prometheus collectors
│   └── store.py             in-memory task store
├── tests/                   pytest suite (13 tests)
├── k8s/
│   ├── deployment.yaml      Deployment task-api (probes, resources)
│   └── service.yaml         Service task-api (NodePort 30000)
├── monitoring/
│   ├── prometheus.yml       scrape config (job task-api, interval 5s)
│   └── grafana/
│       ├── provisioning/    datasource (uid prometheus) + dashboard provider
│       └── dashboards/      task-api-overview.json (4 panels)
├── scripts/
│   ├── setup_check.sh       preflight check of every tool
│   ├── prepare.sh           pre-pull images, start minikube, build, start Jenkins
│   ├── reset.sh             clean state (keeps the code and the git history)
│   ├── traffic.sh           generate load (incl. invalid requests)
│   ├── start_jenkins.sh     download + start jenkins.war as this user
│   ├── stop_jenkins.sh      stop it again
│   ├── jenkins_setup.sh     create the job, trigger a build, show the result
│   ├── git_conflict_demo.sh real merge conflict in a throw-away clone
│   └── jenkins/             plugin list + Groovy init script (admin/admin)
├── Dockerfile               python:3.11-slim, non-root, HEALTHCHECK
├── Jenkinsfile              CI/CD pipeline (7 stages)
├── demo.sh                  the presentation script
├── requirements.txt         pinned runtime dependencies
├── requirements-dev.txt     pinned test dependencies
├── README.md  DEMO_COMMANDS.md  NARRATION_SCRIPT.md
├── VIVA_QA.md  TEAM_TASKS.md  TROUBLESHOOTING.md
```

---

## 4. Quick start

```bash
# 0) check that every tool is installed
bash scripts/setup_check.sh

# 1) prepare everything (images, minikube, jenkins)
bash scripts/prepare.sh

# 2) run the full demo
bash demo.sh

# 3) or one section at a time
bash demo.sh git
bash demo.sh jenkins
bash demo.sh docker
bash demo.sh k8s
bash demo.sh prom
bash demo.sh grafana
bash demo.sh trouble

# 4) clean up again
bash scripts/reset.sh
```

### Run the application locally

```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt -r requirements-dev.txt
.venv/bin/python -m pytest -q
.venv/bin/gunicorn --bind 0.0.0.0:8000 app.app:app
curl http://localhost:8000/health
```

### URLs of the running system

| Service | URL | Credentials |
|---------|-----|-------------|
| Task API | http://localhost:8000/health | - |
| Jenkins | http://localhost:8080 | admin / admin |
| Prometheus | http://localhost:9090/targets | - |
| Grafana | http://localhost:3000 | admin / admin |
| GitHub | https://github.com/atharvadhanwate11/devops-demo-app | - |

---

## 5. The CI/CD pipeline (Jenkinsfile)

| Stage | What it does |
|-------|--------------|
| Checkout | `checkout scm` (the pipeline definition itself comes from Git) |
| Install & Test | venv + `pip install` + `pytest -v` |
| Build Docker Image | `docker build -t task-api:1.0 .` |
| Push Docker Image | only when the parameter `PUSH_IMAGE` is true (credential `dockerhub`) |
| Load Image into Minikube | `minikube image load task-api:1.0` |
| Deploy to Kubernetes | `kubectl apply` + `rollout restart` + `rollout status --timeout=180s` |
| Smoke Test | `kubectl exec deploy/task-api -- python -c "urlopen('http://localhost:8000/health')"` |

`triggers { pollSCM('H/2 * * * *') }` makes Jenkins look for new commits every
two minutes. The `post` block prints a summary for success and failure.

---

## 6. Team work

Every teammate makes their own commit and pull request - see
[TEAM_TASKS.md](TEAM_TASKS.md). The git history must show four different
authors.
