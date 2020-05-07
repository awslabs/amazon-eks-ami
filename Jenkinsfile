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
            sh 'make -j 1.13 1.14'
        }
    } catch (Exception ex) {
        echo "ERROR: ${ex.toString()}"
        slackSend color: 'danger', message: "eks-ami ${env.BRANCH_NAME}: failure: <${env.BUILD_URL}/console|(output)>"
        currentBuild.result = 'FAILURE'
    }
}
