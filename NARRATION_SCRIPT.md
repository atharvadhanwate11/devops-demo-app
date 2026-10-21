# NARRATION SCRIPT (12-15 minutes)

Word-for-word narration. `[]` = stage direction. `CUE:` = what the speaker
does or says at that moment.

---

## INTRO - all four (0:00 - 0:30)

> "Hello everyone. Today we are going to show a complete DevOps pipeline, end
> to end, on a small but real application.
>
> We start with our code. We push it to GitHub. GitHub tells Jenkins that
> something changed. Jenkins tests the code, builds a Docker image, and
> deploys it to a Kubernetes cluster. Prometheus watches the running
> application and collects the metrics. Grafana shows those metrics on a
> dashboard. And at the end we break the deployment on purpose and fix it
> together.
>
> So the whole chain is: code, Git, Jenkins, Docker, Kubernetes, Prometheus,
> Grafana. Let us start with Git."

`CUE: All four stand at the terminal. The screen shows the terminal in
~/devops-demo-app. Do not clear the screen yet.`

---

## STUDENT 1 - GIT (0:30 - 2:15)

`CUE: Student 1 steps to the terminal.`

> "I will start with version control, because everything else depends on it.
>
> Git is a version control system. Every change is a commit, and every commit
> has an author, a message and a parent. That gives us a complete history that
> we can always go back to."

`CUE: Run "git log --oneline --graph --all --decorate".`

> "This is our history. Every line is one commit. The graph shows the branches
> and the merge commits. You can see the feature branches that we developed in
> parallel, and you can see the merge commits where they came back together."

`CUE: Run "git branch -a -vv" and then "git remote -v".`

> "We work with a branching model. Main is the stable version. Develop is the
> integration branch. And every task gets its own feature branch, like
> feature/health-endpoint or feature/metrics. That way several people can work
> at the same time without stepping on each other."

`CUE: Run "gh pr list --state all" and switch to the GitHub browser tab.`

> "When a branch is finished, we open a pull request on GitHub. The pull
> request is a request to merge the branch. Here we can see the pull requests
> we already made, and the ones that are merged. Notice that a merge creates
> a merge commit, so the history keeps a record of both sides."

`CUE: Back to the terminal. Run "bash scripts/git_conflict_demo.sh".`

> "Now something that happens to every team. Two people change the same line
> of the same file, and Git does not know which version is right. This is
> called a merge conflict."

`CUE: Point at the conflict markers in the output.`

> "Git marks the conflict with these three lines. The developer has to
> decide which value is correct, delete the markers, and commit. Our script
> does exactly that, in a throw-away copy of the repository, so the real
> repository is never touched. And it is repeatable - we can run it as many
> times as we want."

`CUE: Press ENTER to continue.`

---

## STUDENT 2 - JENKINS (2:15 - 4:15)

`CUE: Student 2 steps to the terminal.`

> "GitHub holds the code, but somebody has to build and test it. That is the
> job of Jenkins, our CI/CD server."

`CUE: Run "cat Jenkinsfile".`

> "The whole pipeline is written in a file called Jenkinsfile, and that file
> lives in Git, next to the code. That is important: the pipeline is reviewed
> like any other code.
>
> There are seven stages. Checkout. Install and Test. Build Docker Image.
> Push Docker Image, but only when we ask for it. Load the image into the
> Kubernetes cluster. Deploy to Kubernetes. And finally a smoke test that
> calls the health endpoint from inside the running pod."

`CUE: Switch to the Jenkins browser tab (http://localhost:8080).`

> "Here is the Jenkins user interface. The job is called task-api-pipeline.
> It was created automatically from our public GitHub repository, so there was
> no clicking. The pipeline also polls GitHub every two minutes, so a new push
> starts a build automatically."

`CUE: Back to the terminal. Run "bash scripts/jenkins_setup.sh --trigger".`

> "Here we trigger a build through the Jenkins REST API and wait for the
> result. Look at the stages: the tests run, the image is built, the image is
> loaded into the cluster, the deployment is updated, and the smoke test
> passes."

`CUE: Wait for "BUILD RESULT: SUCCESS".`

> "The build is successful. That means one command moved our code from a Git
> commit to a running application in the cluster."

`CUE: Run "kubectl rollout history deployment/task-api".`

> "And you can see it in the cluster. The deployment now has a new revision.
> The pipeline really deployed the new version."

`CUE: Press ENTER to continue.`

---

## STUDENT 3 - DOCKER (4:15 - 6:15)

`CUE: Student 3 steps to the terminal.`

> "Before Kubernetes, we need a package that contains the application and
> everything it needs. That is Docker."

`CUE: Run "cat Dockerfile".`

> "The Dockerfile is the recipe. We start from a pinned Python image. We copy
> the requirements file first and install the dependencies, so Docker can
> cache that layer. Then we copy the application code. Then we create a
> normal user and switch to it, so the container never runs as root. We also
> declare a health check, and the last line is the command that starts the
> server."

`CUE: Run "docker build -t task-api:1.0 ." and then "docker images task-api".`

> "The build finishes in a few seconds and we get an image. The image is
> about 48 megabytes. It is read-only and it is versioned, so we can always
> go back to an older version."

`CUE: Run "docker run -d --name task-api-demo -p 8000:8000 task-api:1.0" and "docker ps".`

> "Starting a container from that image is one command. The container is
> running, and port 8000 on our machine is mapped to port 8000 inside the
> container."

`CUE: Run the curl commands for /health, POST /tasks, GET /tasks.`

> "And now the API is live. The health endpoint answers, and we can create a
> task and read the list back."

`CUE: Run the two validation commands (400 and 422).`

> "The API also validates the input. If the title is missing, we answer 400,
> bad request. If the title is longer than 100 characters, we answer 422,
> unprocessable entity. That is the application protecting itself."

`CUE: Run "docker inspect --format '{{.State.Health.Status}}' task-api-demo" and "docker logs --tail 10 task-api-demo".`

> "Docker also checks the health of the container by itself, and we can read
> the application logs with docker logs."

`CUE: Run "docker stop task-api-demo && docker rm task-api-demo".`

> "We stop the container and remove it. The image stays, ready for the
> cluster."

`CUE: Press ENTER to continue.`

---

## STUDENT 4 - KUBERNETES (6:15 - 8:30)

`CUE: Student 4 steps to the terminal.`

> "A container on one machine is not enough. Kubernetes runs the containers
> for us, restarts them when they die, and gives us a stable address for
> them. We use Minikube, which is a real Kubernetes cluster running on this
> laptop."

`CUE: Run "minikube status" and "kubectl get nodes -o wide".`

> "One node, and kubectl talks to it. Everything we show now is exactly what
> you would do in a production cluster."

`CUE: Run "minikube image load task-api:1.0".`

> "First we load the image we built with Docker into the cluster. Now the
> cluster does not need to download anything from the internet."

`CUE: Run "cat k8s/deployment.yaml" (point at the probes) and "cat k8s/service.yaml".`

> "Two files describe the application. The Deployment says: run three copies
> of the task-api image, and here is how to check if a copy is alive. The
> readiness probe tells Kubernetes when the pod may receive traffic, the
> liveness probe tells Kubernetes when to restart it. The Service gives the
> group of pods a stable name and port."

`CUE: Run "kubectl apply -f k8s/deployment.yaml", "kubectl rollout status ...", "kubectl get pods -l app=task-api -o wide".`

> "We apply the manifests and wait for the rollout. All pods are running."

`CUE: Run "kubectl scale deployment task-api --replicas=3" and "kubectl get pods -l app=task-api".`

> "We scale to three replicas. The Service now balances the traffic over the
> three pods."

`CUE: Delete one pod: POD=$(...); kubectl delete pod $POD — then sleep 10; kubectl get pods -l app=task-api.`

> "Now the self-healing. We delete one pod. Ten seconds later, look: there
> are three pods again. Kubernetes noticed and created a new one. Nobody
> restarted anything by hand."

`CUE: Run the port-forward and curl.`

> "Finally we reach the service. We forward the port of the Service to our
> machine, and the API answers. The same URL is now served by three pods
> behind one address."

`CUE: Switch to the browser tab http://localhost:8000/health briefly, then press ENTER.`

---

## ALL FOUR - PROMETHEUS (8:30 - 10:00)

`CUE: All four stand together again.`

> "So far the application is running, but nobody knows how it behaves. That
> is where monitoring comes in."

`CUE: Run "cat monitoring/prometheus.yml".`

> "Prometheus pulls metrics from the application. Every five seconds it
> fetches the metrics endpoint. The configuration says: the job is called
> task-api, the path is /metrics, and the target is host.docker.internal on
> port 8000."

`CUE: Run "bash scripts/traffic.sh 15 1".`

> "We generate some traffic. Notice that the script also sends a few invalid
> requests on purpose, so we can see error responses in the metrics as
> well."

`CUE: Run the targets query and the tasks_created_total query.`

> "First we ask Prometheus: is my target up? The answer is up, the green
> line. Then we ask a real question: how many tasks were created? We get a
> number back. Prometheus stores the time series and calculates rates over
> them."

`CUE: Switch to the browser tab http://localhost:9090/targets and then the Graph tab.`

> "Here is the target in the web interface, and here is the graph of the
> requests per second. Prometheus has been collecting all of this while we
> were talking."

`CUE: Press ENTER to continue.`

---

## ALL FOUR - GRAFANA (10:00 - 11:15)

`CUE: All four.`

> "Prometheus has the numbers, but reading raw graphs is not friendly.
> Grafana turns the numbers into a dashboard."

`CUE: Show the docker run command for grafana and the provisioning folders.`

> "We run Grafana in a container. Notice the two mounted folders: the
> provisioning folder and the dashboards folder. That means the datasource and
> the dashboard are created from files at start-up. No clicking, fully
> automatic, and the dashboard is versioned in Git like everything else."

`CUE: Run the datasource and dashboard API checks.`

> "We verify it through the API. The Prometheus datasource exists with the id
> prometheus, and the dashboard Task API - Overview exists."

`CUE: Run traffic again in the background, then switch to the Grafana browser tab.`

> "Look at the dashboard. Four panels. Top left: is the service up or down,
> straight from the Prometheus up metric. Top right: tasks created per second.
> Bottom left: the 95th percentile latency, the slowest 5 out of 100
> requests. Bottom right: requests per second split by status code, so you
> can see the 400s and the 422s. All of that is live data, collected by
> Prometheus and drawn by Grafana."

`CUE: Press ENTER to continue.`

---

## ALL FOUR - TROUBLESHOOTING (11:15 - 14:00)

`CUE: All four. This is the important part - slow down.`

> "Everything works now. The real skill is not building it, it is fixing it
> when it breaks. So we break it on purpose, and we fix it together."

`CUE: Run "kubectl get pods -l app=task-api" and curl the health endpoint.`

> "First, the baseline. Everything is healthy and the API answers."

`CUE: Run the sed that changes the image tag, then "git diff k8s/deployment.yaml", then kubectl apply, then sleep 20 and kubectl get pods.`

> "We change the image tag to task-api:invalid. That image does not exist.
> Git shows us the change immediately, because the manifest is version
> controlled. We apply it and wait."

`CUE: Point at the pod status.`

> "And there it is: ErrImagePull, then ImagePullBackOff. The new pod can
> never start."

`CUE: Run the curl to the service.`

> "But notice something very important: the old pods are still serving. The
> API still answers. A rolling update protects the service while the new
> version is broken. That is why we did not lose the application."

`CUE: Now the four tools, one by one.`

> "Now we diagnose, and each of us uses a different tool.
>
> Student 1 uses Kubernetes:"

`CUE: Student 1 runs: BADPOD=$(kubectl get pods -l app=task-api -o jsonpath=...); kubectl describe pod $BADPOD | tail -n 18.`

> "The events at the bottom of describe tell us exactly what happened:
> failed to pull the image, because the image tag does not exist. Kubernetes
> itself tells us the answer."

`CUE: Student 2 runs: docker images task-api; docker image inspect task-api:invalid.`

> "Student 2 uses Docker. The list of images shows only task-api:1.0. And
> when we ask Docker to inspect task-api:invalid, it fails: no such image.
> So Docker confirms the image was never built."

`CUE: Student 3 runs: git diff k8s/deployment.yaml; git log --oneline -n 3 -- k8s/deployment.yaml.`

> "Student 3 uses Git. The diff shows the exact line that we broke, and the
> log shows who last changed that file. Git tells us what changed and when."

`CUE: Student 4 runs: kubectl rollout history deployment/task-api.`

> "Student 4 uses Kubernetes history. We can see which revision is the good
> one, and that is exactly what the rollback command uses."

`CUE: Show Prometheus: curl -s 'http://localhost:9090/api/v1/query?query=up%7Bjob%3D%22task-api%22%7D'.`

> "And one more tool: Grafana and Prometheus still show the service as UP,
> because the old pods are still serving traffic. The dashboard stays green.
> That is useful information: the application is not down, only the new
> version is broken."

`CUE: Run the sed back, kubectl apply, kubectl rollout status, git diff --stat.`

> "Now we fix it. We put the correct tag back and apply it again. The
> rollout finishes, and git diff --stat prints nothing, because the file is
> identical to the committed version again.
>
> The alternative would have been kubectl rollout undo, which rolls back to
> the previous revision of the deployment."

`CUE: Run kubectl get pods and curl the health endpoint.`

> "All pods are running and the API answers. The incident is closed."

`CUE: Press ENTER for the last time.`

---

## CONCLUSION - all four (14:00 - 14:30)

`CUE: All four together, facing the camera.`

> "So, what did we just build?
>
> We wrote a small REST API. We put it in Git, so the code is reviewed and the
> history is recorded. Jenkins watches Git, and when something changes it
> tests the code, builds a Docker image, and deploys that image to
> Kubernetes, which keeps the application running and restarts it if it
> crashes. Prometheus collects the metrics from the running application, and
> Grafana turns them into a dashboard. And when something breaks, all four
> tools together tell us what happened.
>
> That is the whole DevOps pipeline: code, Git, Jenkins, Docker, Kubernetes,
> Prometheus, Grafana. Thank you."

`CUE: End of recording.`

---

## Timing summary

| Part | Speaker | Time |
|------|---------|------|
| Intro | all four | 0:00 - 0:30 |
| Git | Student 1 | 0:30 - 2:15 |
| Jenkins | Student 2 | 2:15 - 4:15 |
| Docker | Student 3 | 4:15 - 6:15 |
| Kubernetes | Student 4 | 6:15 - 8:30 |
| Prometheus | all four | 8:30 - 10:00 |
| Grafana | all four | 10:00 - 11:15 |
| Troubleshooting | all four | 11:15 - 14:00 |
| Conclusion | all four | 14:00 - 14:30 |
