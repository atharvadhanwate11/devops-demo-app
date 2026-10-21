# TEAM TASKS

Each teammate must make their **own real commit and pull request** using their
own Git identity. The repository history must show four different authors, so
nobody commits as anybody else.

**Repository:** https://github.com/atharvadhanwate11/devops-demo-app
**Base branch for every task:** `develop`

---

## How to work on your task (same for everybody)

```bash
# 1. clone the repo (use your own GitHub account)
git clone https://github.com/atharvadhanwate11/devops-demo-app.git
cd devops-demo-app

# 2. create your branch from develop
git checkout develop
git pull
git checkout -b <your-branch-name>

# 3. configure YOUR identity (do not copy someone else's)
git config user.name  "Your Name"
git config user.email "your.email@example.com"

# 4. make the change, run the tests, commit
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt -r requirements-dev.txt
.venv/bin/python -m pytest -q
git add -A
git commit -m "<commit message from your task>"

# 5. push and open a pull request into develop
git push -u origin <your-branch-name>
gh pr create --base develop --head <your-branch-name> \
  --title "<title>" --body "<what changed and why>"
```

---

## Student 1 - Git & branching (owner of the Git section)

| Item | Value |
|------|-------|
| Branch | `feature/git-workflow` |
| File to change | `app/config.py` |
| What to change | Raise `MIN_TITLE_LENGTH` from `1` to `2` and add a comment `# min characters allowed in a title` above it. |
| Commit message | `feat(config): enforce a minimum title length of 2 characters` |
| Extra step | In `tests/test_api.py` add a test `test_create_task_with_one_char_title_returns_400` and commit it with `test: cover one character title validation`. |
| PR title | `feat: enforce minimum title length of 2 characters` |

---

## Student 2 - CI (owner of the Jenkins section)

| Item | Value |
|------|-------|
| Branch | `feature/ci-quality-gate` |
| File to change | `Jenkinsfile` |
| What to change | In the `Install & Test` stage add one line that runs `flake8 --version` style linting - simplest version: add a step `sh 'python -m compileall -q app'` right before the pytest step so the CI also fails on syntax errors. |
| Commit message | `ci: fail the build when the app contains syntax errors` |
| Extra step | Add `scripts/prepare.sh` executable bit fix if needed: `chmod +x scripts/prepare.sh` and commit as `chore: make prepare.sh executable`. |
| PR title | `ci: add syntax check to the pipeline` |

---

## Student 3 - Docker (owner of the Docker section)

| Item | Value |
|------|-------|
| Branch | `feature/docker-optimise` |
| File to change | `Dockerfile` |
| What to change | Add `ENV APP_ENV=production` and change the `HEALTHCHECK` interval from `15s` to `30s` and `--retries` from `3` to `5`. |
| Commit message | `feat(docker): tune image environment and healthcheck timings` |
| Extra step | Add `LABEL org.opencontainers.image.title="task-api"` to the Dockerfile and commit as `docs(docker): add OCI image labels`. |
| PR title | `feat: optimise the Docker image build` |

---

## Student 4 - Kubernetes & Monitoring (owner of the K8s, Prometheus, Grafana sections)

| Item | Value |
|------|-------|
| Branch | `feature/k8s-autoscaling-notes` |
| File to change | `k8s/deployment.yaml` |
| What to change | Add a comment above the `resources:` block: `# requests: what the pod reserves, limits: the hard ceiling` and add `terminationGracePeriodSeconds: 20` to the pod spec. |
| Commit message | `feat(k8s): document resource requests and add graceful termination` |
| Extra step | In `monitoring/prometheus.yml` increase `scrape_interval` from `5s` to `10s` and commit as `chore(monitoring): slow the Prometheus scrape interval to 10s`. |
| PR title | `feat: improve Kubernetes manifest comments and monitoring interval` |

---

## Rules

1. Never commit anybody else's work, never copy another person's Git identity.
2. One task per person, one pull request per task.
3. All pull requests target `develop`. The team lead merges them into `develop`,
   and `develop` is released into `main` afterwards.
4. Every pull request must pass `pytest` in CI (Jenkins) before it is merged.
5. If a merge conflict happens, look at the conflict markers, decide which value
   is correct, resolve it and commit with a `fix:` message. Use
   `bash scripts/git_conflict_demo.sh` to practise.
