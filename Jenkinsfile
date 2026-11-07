pipeline {
    agent { label 'build' }

    options {
        timestamps()
        ansiColor('xterm')
        buildDiscarder(logRotator(numToKeepStr: '20'))
        disableConcurrentBuilds()
        skipDefaultCheckout(true)
    }

    environment {
        JOB_NAME      = 'HANDSON_YOUSUF'
        SOLUTION_NAME = 'handson-yousuf'
        GIT_URL       = 'https://github.com/mansur-yousuf/handson-yousuf.git'
        GIT_BRANCH    = 'main'
        REGISTRY      = 'node5.naasbd.com'
        REPO_IMAGE    = 'node5.naasbd.com/handson_yousuf/mansur'
        BUILDER_NAME  = 'handsonyousuf'
        DOCKER_HOST   = 'unix:///var/run/docker.sock'
    }

    stages {
        stage('Prep workspace') {
            steps {
                cleanWs()
                sh '''
                    set -euo pipefail
                    echo "Workspace prepared."
                '''
            }
        }

        stage('Clone') {
            steps {
                retry(2) {
                    // Public GitHub repo: no credentials needed
                    sh '''
                        set -euo pipefail
                        rm -rf "$SOLUTION_NAME"
                        git clone --depth 1 --single-branch --branch "$GIT_BRANCH" "$GIT_URL" "$SOLUTION_NAME"
                        ls -alh "$SOLUTION_NAME"
                    '''
                }
            }
        }

        stage('Read project version') {
            steps {
                script {
                    def versionFile = "${env.SOLUTION_NAME}/package.json"

                    if (!fileExists(versionFile)) {
                        error 'package.json not found.'
                    }

                    def version = sh(
                        script: "jq -r .version ${versionFile}",
                        returnStdout: true
                    ).trim()

                    if (!version || version == 'null') {
                        error "Version field not found in ${versionFile}."
                    }

                    env.VERSION = version
                    echo "Detected version: ${env.VERSION}"
                }
            }
        }

        stage('Verify version') {
            steps {
                script {
                    if (!env.VERSION?.trim()) {
                        error('Project version is empty — aborting.')
                    }
                    echo "Using VERSION=${env.VERSION}"
                }
            }
        }

        stage('Build image (buildx)') {
            steps {
                sh '''
                    set -euo pipefail
                    export DOCKER_BUILDKIT=1
                    docker buildx version || true
                    docker buildx create --name "$BUILDER_NAME" --driver docker-container --use 2>/dev/null || docker buildx use "$BUILDER_NAME"
                    docker buildx inspect --bootstrap
                    docker buildx build \
                        --platform linux/amd64 \
                        --progress=plain \
                        -t "$REPO_IMAGE:$VERSION" \
                        -f "$SOLUTION_NAME/Dockerfile" \
                        "$SOLUTION_NAME/" \
                        --load
                '''
            }
        }

        stage('Login registry') {
            steps {
                // Pushing to a registry still needs an account, even if the project is public.
                // Create a Jenkins "Username with password" credential with this ID.
                withCredentials([usernamePassword(
                    credentialsId: 'HANDSON-REGISTRY',
                    usernameVariable: 'REG_USER',
                    passwordVariable: 'REG_PASS'
                )]) {
                    sh '''
                        set -euo pipefail
                        echo "$REG_PASS" | docker login "$REGISTRY" -u "$REG_USER" --password-stdin
                    '''
                }
            }
        }

        stage('Push image') {
            steps {
                retry(2) {
                    sh '''
                        set -euo pipefail
                        docker push "$REPO_IMAGE:$VERSION"
                    '''
                }
            }
        }
    }

    post {
        always {
            sh '''
                docker logout "$REGISTRY" || true
                docker image prune -f || true
            '''
            cleanWs()
        }
        success { echo "✅ Build & push OK: ${env.REPO_IMAGE}:${env.VERSION}" }
        failure { echo '❌ Build failed.' }
    }
}
