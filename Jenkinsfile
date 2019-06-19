#!/usr/bin/env groovy
// Load the OG Jenkins Library
@Library('OGJenkinsLib@3.6.1') _

final GIT_REPOSITORY_NAME = 'amazon-eks-ami'
final KUBERNETES_VERSION = '1.12.7'
final PACKER_IMAGE_MANIFEST = 'manifest.json'
def config = [:]  // Pipeline configuration

def containers = [
  OGContainer('devops', "${env.INTERNAL_REGISTRY_HOSTNAME}/devops", '2.3.0', [resourceLimitCpu: '2000m', resourceLimitMemory: '2Gi'])
]

OGPipeline(containers) {
  stage('Setup') {
    // Where the pipeline configuration will be stored
    def scmVars      // SCM

    // Checkout the pipeline code first so that the properties.groovy file can
    // then be loaded
    scmVars = checkout scm
    config = load('Jenkinsfile.properties')

    // Get all relevant Git information
    config.git = [:]
    config.git.isPullRequest = env.CHANGE_ID.asBoolean() // Only set if its a pull request
    if (config.accountIds.isEmpty()) {
      if (config.git.isPullRequest){
        config.accountIds = config.awsAccountsOnPullRequest
      } else {
        config.accountIds = config.awsAccountsOnMerge
      }
    }

    // Check version
    container('devops') {
      sh 'packer version'
      sh 'aws --version'
    }

    // Save the configuration as an artifact
    utils.createArtifact('initialConfig', config)
  }

  stage('Bake Encrypted AMIs') {
    def jobs = config.accountIds.collectEntries { accountId ->
      def job = {
        withCredentials([usernamePassword(credentialsId: accountId, passwordVariable: 'AWS_SECRET_ACCESS_KEY', usernameVariable: 'AWS_ACCESS_KEY_ID')]) {
          if (config.dry) {
            echo "Would have ran: 'make VERSION=${KUBERNETES_VERSION} k8s'"
            sh "touch ${PACKER_IMAGE_MANIFEST}"
          } else {
            container('devops') {
              sh "make AMI_REGIONS=${config.regions} VERSION=${KUBERNETES_VERSION} k8s"
            }
          }
        }
      }
      [accountId, job]
    }

    parallel jobs

    archiveArtifacts(artifacts: PACKER_IMAGE_MANIFEST, fingerprint: true)
  }
}
