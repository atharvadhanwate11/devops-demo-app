# PROGRESS

Overnight autonomous run - DevOps demo project.
All times are the local clock of the run (see the bottom for the timeline).

Rules followed: no questions asked, every phase appends to this file, a step
that fails 3 times is documented in BLOCKERS.md and skipped with the
documented fallback, nothing interactive is run.

---

## Phase 0 - Toolchain check - PASS
- `scripts/setup_check.sh` -> `RESULT: ALL OK (15 checks passed, 0 failed)`.
- Evidence: git, docker, docker compose, java 17, python3 + venv, pip, jq,
  curl, unzip, kubectl, minikube, gh, minikube driver check.
- Time: 2026-10-22 10:05

## Phase 1 - Application + unit tests - PASS
- 13 pytest tests pass: `.venv/bin/python -m pytest -q`.
- Live checks: `/health` 200, `POST /tasks` 201, `GET /tasks` 200,
  `DELETE /tasks/{id}` 200 and 404, validation 400 and 422,
  `/metrics` exposes `tasks_created_total`, `http_requests_total`,
  `request_latency_seconds_*`, `tasks_current`.
- Time: 2026-10-22 10:20

## Phase 2 - Git / GitHub - PASS
- Public repo `atharvadhanwate11/devops-demo-app` created.
- 5 conventional commits on `main`; branches `develop`,
  `feature/health-endpoint`, `feature/metrics`.
- PRs #1-#6 merged with merge commits; one real conflict in
  `tests/test_api.py` resolved and committed (`5b84968`).
- `scripts/git_conflict_demo.sh` ran twice, exit 0, working tree untouched.
- Time: 2026-10-22 11:40

## Phase 3 - Docker - PASS
- `task-api:1.0` built, 47,636,749 bytes (~48 MB, 197 MB virtual).
- Runs as `appuser`, HEALTHCHECK reports `healthy`.
- All endpoints + metrics verified against the container.
- Time: 2026-10-22 12:30

## Phase 4 - Kubernetes / Minikube - IN PROGRESS
- `minikube start --driver=docker` runs detached, log
  `/home/dhance/scratch/minikube_docker.log`.
- The kicbase image (507 MB) is still downloading (26 % at 13:05, ~160 KB/s
  because three downloads share the link).
- Fallback documented in BLOCKERS.md: `--driver=none` as root with
  `HOME=/home/dhance`.
- Time: started 12:40

## Phase 5 - Jenkins - IN PROGRESS
- `scripts/start_jenkins.sh` runs detached, log
  `/home/dhance/scratch/jenkins_start.log`; the war (2.580.1) is downloading.
- Budget: 45 minutes from 12:55, then fall back to the documented manual
  configuration (BLOCKERS.md) and continue.
- Time: started 12:55

## Phase 6 - Prometheus - PASS
- `docker run` with the mounted `monitoring/prometheus.yml`, extra host
  `host.docker.internal:host-gateway`.
- Targets: `prometheus status=up`, `task-api status=up`
  (`http://host.docker.internal:8000/metrics`).
- `sum(tasks_created_total)` returns a value; `rate(http_requests_total[1m])`
  returns 200/201/400/422 rates (the invalid requests are deliberate).
- `bash scripts/traffic.sh 15 1` -> created=15 deleted=15 ok=60 unexpected=0.
- Time: 2026-10-22 13:10

## Phase 7 - Grafana - PENDING

## Phase 8 - Troubleshooting scenario - PENDING

## Phase 9 - Full `demo.sh` end-to-end - PENDING

## Phase 10 - Docs - IN PROGRESS
- `README.md`, `DEMO_COMMANDS.md`, `VIVA_QA.md`, `TEAM_TASKS.md` written.
- `NARRATION_SCRIPT.md` written (12-15 min, word for word, split by student).
- `TROUBLESHOOTING.md` written (24 real problems with fixes).
- Time: 2026-10-22 13:15

---

## Decisions taken without asking (autonomy rules)

1. **Team member names** - the real names were never supplied, so
   `TEAM_TASKS.md` and `NARRATION_SCRIPT.md` use "Student 1..4" placeholders
   that map to the roles Git / Jenkins / Docker / Kubernetes. Replace the
   labels with the real names in one pass (`sed -i 's/Student 1/<Name>/'`).
2. **Monitoring host** - Prometheus scrapes `host.docker.internal:8000`,
   which works both for a plain Docker container and for the `kubectl
   port-forward` on the host. No extra host entry is needed on the demo
   machine.
3. **Grafana provisioning** - the datasource and the dashboard are mounted as
   read-only files, so Grafana needs no click-through setup.
4. **Jenkins admin** - `admin/admin` through a Groovy init script, because
   the setup wizard is interactive and cannot be used in an autonomous run.
5. **Ports** - 8000 (app), 8080 (Jenkins), 9090 (Prometheus), 3000 (Grafana),
   30000 (NodePort). All fixed so the narration can quote them.
