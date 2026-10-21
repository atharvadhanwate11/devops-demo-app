# VIVA Q&A - 20 likely questions

Short, correct answers. If a question is about something you have not seen in
the demo, say so and explain what you would check.

---

### 1. What is the difference between a Docker image and a Docker container?
An **image** is a read-only template (layers of files plus instructions) built
with `docker build`. A **container** is a running instance of that image -
`docker run` starts one. One image can have many containers. Deleting a
container does not delete the image.

### 2. What is the Dockerfile and why is it layered?
The Dockerfile is the recipe of the image. Each instruction creates a layer.
Layers are cached: if an earlier layer does not change, Docker reuses it. That
is why we copy `requirements.txt` **before** the application code - changing
the code then does not force a slow re-install of the dependencies.

### 3. What does `EXPOSE 8000` do?
It only documents which port the container listens on. It does not publish the
port. To reach the container you use `-p 8000:8000` (`docker run`) or a
Kubernetes Service.

### 4. What is a Pod in Kubernetes?
The smallest unit that Kubernetes can schedule. A Pod runs one or more
containers that share the same network address and the same volume. In our
demo every Pod runs exactly one container: the Task Manager API.

### 5. What is a Deployment?
A controller that keeps a desired number of identical Pods running. It
creates new Pods when pods die, and it performs **rolling updates** when the
image changes: it starts new Pods, waits until they are ready, and only then
removes the old ones. That is why the service stays available during a
deployment.

### 6. What is a Service?
A stable name and address for a group of Pods. A Service has a label
selector; every Pod with that label is added to its endpoint list, so the
Service load-balances over all of them. Our Service is a `NodePort`
(`30000 -> 8000`); inside the cluster we use `kubectl port-forward`.

### 7. Why do we need both a readiness probe and a liveness probe?
* **Readiness** answers "may this Pod receive traffic?". If it fails, the Pod
  stays out of the Service endpoints but is not restarted.
* **Liveness** answers "is this Pod still working?". If it fails, Kubernetes
  restarts the container.
Using only a liveness probe would restart a Pod that is merely slow to start;
using only a readiness probe would never restart a hung process.

### 8. What is `imagePullPolicy: IfNotPresent` and why does it matter here?
It tells Kubernetes to use the image that is already on the node and only pull
if it is missing. We load the image into Minikube with
`minikube image load`, so the cluster never needs to reach a registry. That is
also why an invalid tag fails fast with `ImagePullBackOff` instead of pulling
something wrong.

### 9. What is a rolling update?
Replacing running Pods with new ones without downtime: Kubernetes creates the
new ReplicaSet, waits for the new Pods to pass the readiness probe, and then
removes the old Pods one by one. `kubectl rollout status` waits for it to
finish, `kubectl rollout undo` reverts to the previous revision.

### 10. Why does `ImagePullBackOff` happen?
The kubelet cannot download the image: the tag does not exist, the registry is
unreachable, or the image name is misspelled. Kubernetes keeps retrying with
an increasing delay, which is why the status says `ErrImagePull` first and
then `ImagePullBackOff`. In our demo we deliberately point the Deployment at
`task-api:invalid`, which does not exist.

### 11. How does Prometheus collect metrics? Push or pull?
**Pull.** Prometheus is configured with a list of targets and scrapes them
every `scrape_interval` seconds (5s in our setup) over HTTP, usually
`/metrics`. The application does not know that Prometheus exists. The
advantage: the monitoring system can be restarted or moved without touching
the application.

### 12. What is the difference between a Counter, a Gauge and a Histogram?
* **Counter** - only goes up: `tasks_created_total`, `http_requests_total`.
* **Gauge** - goes up and down: `tasks_current`.
* **Histogram** - buckets of observed values: `request_latency_seconds`
  (`_bucket`, `_sum`, `_count`).
`rate()` and `histogram_quantile()` work on counters and histograms.

### 13. What does `rate(tasks_created_total[1m])` mean?
The average number of tasks created per second over the last minute. Prometheus
computes the increase of the counter inside the 1 minute window and divides it
by 60. `rate()` is designed for counters, which is why you never use it on a
gauge.

### 14. What is `histogram_quantile(0.95, ...)` doing?
It reads the histogram buckets, assumes the requests were spread evenly
inside each bucket, and estimates the value below which 95 % of the requests
finished. That value is the p95 latency - "95 out of 100 requests were faster
than this".

### 15. What is a merge conflict?
Two branches changed the same lines of the same file and Git cannot decide
which version is correct. Git stops the merge and writes conflict markers
(`<<<<<<<`, `=======`, `>>>>>>>`) into the file. A human resolves it, removes
the markers, and commits. `scripts/git_conflict_demo.sh` shows this in a
throw-away clone.

### 16. What does CI/CD mean?
* **CI (Continuous Integration)**: every push is automatically built and
  tested, so problems are found in minutes instead of at release time.
* **CD (Continuous Delivery/Deployment)**: the tested build is automatically
  packaged and deployed to the target environment.
Our Jenkins pipeline does both: checkout -> test -> build image -> load into
the cluster -> deploy -> smoke test.

### 17. What is Jenkins and what is a pipeline?
Jenkins is an automation server. A pipeline is the definition of the steps,
written in the `Jenkinsfile`. Ours is a **declarative pipeline** with seven
stages and a `post` block. `pollSCM('H/2 * * * *')` makes Jenkins check
GitHub every two minutes for new commits.

### 18. What is a Git branch and a pull request?
A branch is a movable pointer to a commit, so several people can work in
parallel. A pull request asks GitHub to merge one branch into another. It is
reviewed, it can be built automatically, and the merge creates a merge commit
that records both lines of work.

### 19. What is Minikube and why do we use it?
Minikube runs a real, single node Kubernetes cluster on a laptop. It gives us
the real `kubectl`, real Deployments, real Services and real probes without
paying for a cloud cluster. We use the Docker driver, so the Kubernetes node
itself is a container.

### 20. A pod is not starting. How do you debug it, in order?
1. `kubectl get pods` - what is the status? `Pending`, `ImagePullBackOff`,
   `CrashLoopBackOff`?
2. `kubectl describe pod <name>` - read the **Events** at the bottom.
3. `kubectl logs <name> --previous` - the logs of the crashed container.
4. Is the image there? `docker images` / `minikube image ls`.
5. Is the configuration right? `kubectl get deployment -o yaml`,
   `kubectl describe deployment`.
6. Does the app answer? `kubectl exec deploy/task-api -- python -c "..."`.
In our demo we deliberately use a wrong image tag, and `kubectl describe pod`
tells us exactly that.

---

## Bonus questions

**Q: Why does the Dockerfile use `python:3.11-slim`?**
Pinned base image: reproducible and small (no build tools, no docs).

**Q: Why run as a non-root user?**
Least privilege: a compromised process cannot modify the system or the image.

**Q: What is the HEALTHCHECK in the Dockerfile for?**
Docker itself probes `/health` every 15 s and marks the container `healthy` or
`unhealthy`, so orchestrators and `docker ps` show the real state.

**Q: How do you scale the application?**
`kubectl scale deployment task-api --replicas=3`. The Service then balances
the traffic over the three Pods.

**Q: What would you do if the production cluster was bigger?**
Replace Minikube with a managed cluster (EKS/GKE/AKS), store the image in a
registry (ECR), add `imagePullSecrets`, and use a real ingress controller
instead of NodePort.
