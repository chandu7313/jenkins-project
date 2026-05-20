pipeline {
    agent any

    environment {
        DOCKER_IMAGE   = 'chandu9000/jenkins_devops'
        DOCKER_TAG     = "${env.BUILD_NUMBER}"
        CONTAINER_NAME = 'jenkins_devops_container'
        APP_PORT       = '3000'
    }

    options {
        timeout(time: 15, unit: 'MINUTES')
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    stages {

        stage('Clone Code') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/chandu7313/jenkins-project.git'
            }
        }

        stage('Install Dependencies & Run Tests') {
            steps {
                sh '''
                    docker run --rm \
                    -v $WORKSPACE:/app \
                    -w /app \
                    node:22-alpine \
                    sh -c "npm ci && npm test"
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                sh """
                    docker build \
                        -t ${DOCKER_IMAGE}:${DOCKER_TAG} \
                        -t ${DOCKER_IMAGE}:latest \
                        .
                """
            }
        }

        stage('Docker Login & Push') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'jenkins-project',
                        usernameVariable: 'DOCKER_USERNAME',
                        passwordVariable: 'DOCKER_PASSWORD'
                    )
                ]) {
                    sh """
                        echo \$DOCKER_PASSWORD | docker login -u \$DOCKER_USERNAME --password-stdin
                        docker push ${DOCKER_IMAGE}:${DOCKER_TAG}
                        docker push ${DOCKER_IMAGE}:latest
                    """
                }
            }
        }

        stage('Deploy') {
            steps {
                sh """
                    docker rm -f ${CONTAINER_NAME} || true

                    docker run -d \
                        --name ${CONTAINER_NAME} \
                        --restart unless-stopped \
                        -p ${APP_PORT}:3000 \
                        -e NODE_ENV=production \
                        --memory=512m \
                        --cpus=0.5 \
                        ${DOCKER_IMAGE}:${DOCKER_TAG}
                """
            }
        }

        stage('Health Check') {
            steps {
                sh '''
                    echo "Waiting for application to start..."
                    sleep 5

                    MAX_RETRIES=6
                    RETRY_COUNT=0

                    until curl -sf http://localhost:3000/ > /dev/null 2>&1; do
                        RETRY_COUNT=$((RETRY_COUNT + 1))
                        if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
                            echo "Health check failed after $MAX_RETRIES attempts"
                            docker logs jenkins_devops_container
                            exit 1
                        fi
                        echo "Retry $RETRY_COUNT/$MAX_RETRIES — waiting 5s..."
                        sleep 5
                    done

                    echo "Application is healthy and responding on port 3000"
                    docker ps --filter name=jenkins_devops_container
                '''
            }
        }
    }

    post {
        success {
            echo "✅ Build #${env.BUILD_NUMBER} deployed successfully"
        }

        failure {
            echo "❌ Build #${env.BUILD_NUMBER} failed"
            sh """
                docker rm -f ${CONTAINER_NAME} || true
            """
        }

        always {
            // Clean up dangling images to save disk space
            sh 'docker image prune -f || true'
            echo "Pipeline finished — Build #${env.BUILD_NUMBER}"
        }
    }
}