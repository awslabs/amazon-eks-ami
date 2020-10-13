node {
    try {
        stage('checkout') {
            checkout([
                    $class: 'GitSCM',
                    branches: scm.branches,
                    doGenerateSubmoduleConfigurations: scm.doGenerateSubmoduleConfigurations,
                    extensions: [[$class: 'CloneOption', noTags: false, shallow: false, depth: 0, reference: '']],
                    userRemoteConfigs: scm.userRemoteConfigs,
            ])
            tag = sh script: 'git tag --contains HEAD', returnStdout: true
            tag = tag.trim()
            if (tag == '') {
                commit_hash = sh script: 'git rev-parse --verify HEAD | cut -c1-8', returnStdout: true
                commit_hash = commit_hash.trim()
                env.BUILD_TAG = "${env.BRANCH_NAME}-${env.BUILD_NUMBER}-${commit_hash}"
            } else {
                env.BUILD_TAG = tag
            }
        }

        stage('build') {
            withAWS(credentials: 'jenkins-agent', region: 'us-west-2') {
            // test comment
                sh "aws --region us-west-2 ecr get-login-password | docker login --username AWS --password-stdin 876270261134.dkr.ecr.us-west-2.amazonaws.com"
                sh 'make -j2 1.15'
            }
        }
    } catch (Exception ex) {
        echo "ERROR: ${ex.toString()}"
        slackSend color: 'danger', message: "eks-ami ${env.BRANCH_NAME}: failure: <${env.BUILD_URL}/console|(output)>"
        currentBuild.result = 'FAILURE'
    }
}
