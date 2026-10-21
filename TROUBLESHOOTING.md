# TROUBLESHOOTING

Every problem we actually hit while building this project, and how it was
fixed. Use `Ctrl+F` in the terminal.

---

## 1. Docker: "permission denied while trying to connect to the Docker API"

**Symptom**
```
permission denied while trying to connect to the Docker API socket
unix:///var/run/docker.sock
```

**Cause** - your user is not in the `docker` group.

**Fix**
```bash
sudo usermod -aG docker $USER
# log out and back in (or restart the shell) so the new group is picked up
docker ps
```
Inside WSL2 without a usable `sudo` password you can run the command in a root
shell: `wsl -u root -e bash -c "usermod -aG docker $USER"`.

---

## 2. Docker: the image is huge / the build is slow

**Fix** - in the Dockerfile copy `requirements.txt` **before** the application
code. Then a code change reuses the cached dependency layer:

```dockerfile
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt
COPY app/ ./app/
```

---

## 3. Docker: the container restarts and the API loses data

**Cause** - more than one gunicorn worker. The task store is in memory, so
each worker process has its own copy. A task created in worker 1 is unknown in
worker 2, and the Prometheus counters are per process as well.

**Fix** - one worker with several threads:
```
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "1", "--threads", "4", ...]
```

---

## 4. Minikube: `Exiting due to GUEST_MISSING_CONNTRACK` (none driver)

**Fix**
```bash
sudo apt-get install -y crictl        # or download the cri-tools release
sudo curl -Lo /usr/local/bin/crictl \
  https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.37.0/crictl-v1.37.0-linux-amd64.tar.gz
```

---

## 5. Minikube: `Exiting due to NOT_FOUND_CNI_PLUGINS` (none driver)

**Fix**
```bash
sudo apt-get install -y containernetworking-plugins
sudo mkdir -p /opt/cni/bin
sudo cp -a /usr/lib/cni/. /opt/cni/bin/     # minikube looks in /opt/cni/bin
```

---

## 6. Minikube: `Failed to save config: ... permission denied`

**Cause** - a previous run was executed as root and left root-owned files in
`~/.minikube`.

**Fix**
```bash
sudo chown -R $USER $HOME/.minikube
sudo chmod -R u+wrx $HOME/.minikube
minikube delete --all && minikube start --driver=docker
```

---

## 7. Minikube: `DRV_AS_ROOT - the docker driver should not be used with root privileges`

**Cause** - `minikube start --driver=docker` was executed as root.

**Fix** - run it as your normal user. The `none` driver is the only one that
works as root.

---

## 8. Minikube: `minikube image load` says the image was not found in the cluster

**Cause** - the image was built for the wrong architecture, or the load used a
different tag than the Deployment.

**Fix**
```bash
docker images task-api                     # confirm the tag
minikube image ls | grep task-api          # confirm it arrived in the node
kubectl set image deployment/task-api task-api=task-api:1.0
```
Keep `imagePullPolicy: IfNotPresent` so the cluster never tries to pull.

---

## 9. Kubernetes: the pod stays `Pending` with `ErrImagePull` / `ImagePullBackOff`

**Cause** - the image tag does not exist in the registry and is not loaded in
the node.

**Diagnose**
```bash
kubectl describe pod <pod> | tail -n 20     # the Events tell you why
docker image inspect task-api:invalid        # fails -> the image does not exist
```

**Fix** - load the image (`minikube image load task-api:1.0`) or use a tag
that exists in the registry. The demo deliberately breaks this in the
troubleshooting section.

---

## 10. Kubernetes: `kubectl` refuses to talk to the cluster

**Fix**
```bash
minikube status
ls -l ~/.kube/config          # must be owned by you
kubectl config current-context
```

---

## 11. "error: unable to recognize ... server version too new"

**Cause** - the kubectl client is more than one minor version older than the
cluster.

**Fix** - install a matching kubectl:
```bash
curl -Lo kubectl https://dl.k8s.io/release/v1.37.0/bin/linux/amd64/kubectl
sudo install -m755 kubectl /home/$USER/bin/kubectl
```

---

## 12. Port 8000 is already in use

**Find the owner**
```bash
sudo ss -ltnp | grep 8000
lsof -i :8000
```

**Fix** - stop the old process, or use another port:
```bash
kubectl port-forward --address 0.0.0.0 svc/task-api 8080:8000
docker rm -f task-api-demo
```

---

## 13. Prometheus: the target is DOWN

**Check**
```bash
curl -s 'http://localhost:9090/api/v1/targets' | jq '.data.activeTargets[] | {url: .scrapeUrl, health: .health, error: .lastError}'
```

**Causes and fixes**
| Cause | Fix |
|-------|-----|
| The app is not reachable on port 8000 | `curl http://localhost:8000/health` - start the port-forward |
| The container cannot reach the host | add `--add-host=host.docker.internal:host-gateway` to the Prometheus container |
| The port-forward binds only to localhost | use `kubectl port-forward --address 0.0.0.0 ...` |
| Wrong path | the metrics path is `/metrics`, not `/` |

---

## 14. Grafana: "no data" in the panels

**Check**
```bash
curl -s -u admin:admin http://localhost:3000/api/datasources   # is the datasource there?
curl -s 'http://localhost:9090/api/v1/query?query=tasks_created_total'   # does Prometheus have data?
```

**Causes**
* No traffic yet - the metric only exists after the first request.
* The dashboard queries a metric that the app does not expose (check the
  spelling: `tasks_created_total`, not `tasks_created`).
* The time range in Grafana is too small - set it to "Last 5 minutes".
* Prometheus cannot reach the app (see 13).

---

## 15. Grafana: the dashboard does not appear

**Fix** - the provider only reads the dashboards folder every
`updateIntervalSeconds` (10 s). Restart the container and wait:
```bash
docker restart grafana
sleep 15
curl -s -u admin:admin 'http://localhost:3000/api/search?query=Task' | jq
```
Check that the dashboard JSON is valid: `jq empty monitoring/grafana/dashboards/task-api-overview.json`

---

## 16. Jenkins: "cannot connect to the Docker daemon" in the pipeline

**Cause** - the Jenkins process was started without the docker group, or with
a different `PATH`.

**Fix** - start Jenkins as the user who owns the docker group and export the
path before starting it:
```bash
export PATH="$HOME/bin:$PATH"
JENKINS_HOME=~/jenkins/home nohup java -jar ~/jenkins/jenkins.war --httpPort=8080 &
```
Check from inside the pipeline: `sh 'docker ps'`.

---

## 17. Jenkins: the pipeline cannot find kubectl or minikube

**Cause** - they are installed in `~/bin`, which is not in the Jenkins
process environment.

**Fix** - `export PATH="$HOME/bin:$PATH"` in `scripts/start_jenkins.sh` before
launching Java, and make sure `KUBECONFIG` (or `~/.kube/config`) is readable
by the Jenkins user.

---

## 18. Jenkins: "the job was created but the build says no Jenkinsfile"

**Cause** - the job was created as "Pipeline script" instead of "Pipeline
script from SCM", or the branch is wrong.

**Fix** - recreate the job from `config.xml` with
`<scriptPath>Jenkinsfile</scriptPath>` and the branch `*/main`:
```bash
bash scripts/jenkins_setup.sh --no-trigger
```

---

## 19. Jenkins: CSRF crumb error (403)

**Fix** - every write request needs the crumb:
```bash
CRUMB=$(curl -s -u admin:admin http://localhost:8080/crumbIssuer/api/json | jq -r .crumb)
curl -u admin:admin -X POST -H "Jenkins-Crumb: $CRUMB" ...
```
`scripts/jenkins_setup.sh` does this for you.

---

## 20. Git: "Please tell me who you are" or a wrong author in the history

**Fix**
```bash
git config user.name  "Your Name"
git config user.email "you@example.com"
```
Each team member configures **their own** identity - see `TEAM_TASKS.md`.
Never commit as somebody else.

---

## 21. Git: `git push` asks for a username and password forever

**Cause** - no credential helper for GitHub in WSL.

**Fix**
```bash
gh auth setup-git        # use the gh CLI as the credential helper
```
or store a personal access token in `~/.git-credentials` (never in the
repository).

---

## 22. CRLF line endings: `#!/usr/bin/env bash\r: bad interpreter`

**Symptom** - `/bin/bash^M: bad interpreter: No such file or directory`.

**Fix**
```bash
sed -i 's/\r$//' scripts/*.sh demo.sh
```
and keep `.gitattributes` in the repository:
```
* text=auto eol=lf
*.sh text eol=lf
```

---

## 23. The demo script stops at a section and does not continue

**Cause** - a command inside a section returned non-zero and the script uses
`set -uo pipefail` (errors are printed, but a failing command in a pipeline
can still abort a section).

**Fix** - run the section on its own to see the error:
```bash
bash demo.sh k8s
```
and check that the prerequisites are up (`minikube status`, `docker ps`).

---

## 24. Reset the whole environment

```bash
bash scripts/reset.sh          # containers, kubernetes objects, Jenkins, venv
RESET_CLUSTER=1 bash scripts/reset.sh   # also delete the minikube cluster
```
The source code, the git history and the branches are never touched.
