// ---------------------------------------------------------------------------
// DevOps Demo - CI/CD pipeline
//
//   code -> git -> jenkins -> docker image -> minikube/kubernetes -> smoke test
//
// The pipeline runs on the Jenkins master (the local machine) so it can use the
// same docker daemon, kubectl and minikube that the students use.
// ---------------------------------------------------------------------------
pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 30, unit: 'MINUTES')
    }

    parameters {
        booleanParam(
            name: 'PUSH_IMAGE',
            defaultValue: false,
            description: 'Push the Docker image to Docker Hub (needs the dockerhub credentials)'
        )
    }

    environment {
        IMAGE_NAME = 'task-api'
        IMAGE_TAG  = '1.0'
        APP_DIR    = "${WORKSPACE}"
    }

    triggers {
        pollSCM('H/2 * * * *')
    }

    stages {
        stage('Checkout') {
            steps {
                echo "Checking out ${env.BRANCH_NAME ?: 'main'} from GitHub"
                checkout scm
                sh 'git log --oneline -n 3'
            }
        }

        stage('Install & Test') {
            steps {
                sh 'python3 -m venv .venv'
                sh '.venv/bin/pip install --no-cache-dir -r requirements.txt -r requirements-dev.txt'
                sh '.venv/bin/python -m pytest -v'
            }
        }

        stage('Build Docker Image') {
            steps {
                sh 'docker build -t "${IMAGE_NAME}:${IMAGE_TAG}" .'
                sh 'docker images "${IMAGE_NAME}"'
            }
        }

        stage('Push Docker Image') {
            when { expression { return params.PUSH_IMAGE == true } }
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub',
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PASS')]) {
                    sh '''
                        echo "${DOCKER_PASS}" | docker login -u "${DOCKER_USER}" --password-stdin
                        docker push "${IMAGE_NAME}:${IMAGE_TAG}"
                    '''
                }
            }
        }

        stage('Load Image into Minikube') {
            steps {
                sh 'minikube status'
                sh 'minikube image load "${IMAGE_NAME}:${IMAGE_TAG}"'
                sh 'minikube image ls | grep "${IMAGE_NAME}" || true'
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                sh 'kubectl apply -f k8s/deployment.yaml'
                sh 'kubectl apply -f k8s/service.yaml'
                sh 'kubectl rollout restart deployment/task-api'
                sh 'kubectl rollout status deployment/task-api --timeout=180s'
                sh 'kubectl get pods -l app=task-api'
            }
        }

        stage('Smoke Test') {
            steps {
                sh '''
                    kubectl exec deploy/task-api -- python -c "import urllib.request; print(urllib.request.urlopen('http://localhost:8000/health', timeout=5).read().decode())"
                '''
            }
        }
    }

    post {
        success {
            echo "PIPELINE SUCCESSFUL - the new version is running in Kubernetes."
            sh 'kubectl get pods -l app=task-api'
        }
        failure {
            echo "PIPELINE FAILED - check the stage above and the Kubernetes events."
            sh 'kubectl get pods -l app=task-api || true'
            sh 'kubectl describe deployment task-api | tail -n 20 || true'
        }
        always {
            echo "Build finished at ${new Date().toString()}"
        }
    }
}
