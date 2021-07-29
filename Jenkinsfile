#!/usr/bin/env groovy
// Load the OG Jenkins Library
@Library('OGJenkinsLib@3.18.0') _

final GIT_REPOSITORY_NAME = 'amazon-eks-ami'
final KUBERNETES_VERSION = '1.19.8'
final PACKER_IMAGE_MANIFEST = 'manifest.json'
final OG_IMAGE_VERSION = '1.6.0'
def config = [:]  // Pipeline configuration

def containers = [
  OGContainer('devops', "${env.INTERNAL_REGISTRY_HOSTNAME}/devops", '3.8.0', [resourceLimitCpu: '2000m', resourceLimitMemory: '2Gi'])
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

    echo "Initial Configuration: ${utils.jsonify(config)}"

    if (config.accountIds.isEmpty()) {
      if (config.git.isPullRequest){
        echo 'Using default account for pull request build'
        config.accountIds = config.awsAccountsOnPullRequest

      } else {
        echo 'Using default accounts for merge builds'
        config.accountIds = config.awsAccountsOnMerge
      }
    }

    echo "Account IDs to build images for: ${utils.jsonify(config.accountIds)}"

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
        if (config.dry) {
          echo "Would have ran: 'make AMI_REGIONS=${config.regions} kubernetes_version=${KUBERNETES_VERSION} OG_IMAGE_VERSION=${OG_IMAGE_VERSION} k8s'"
          sh "touch ${PACKER_IMAGE_MANIFEST}"
        } else {

          withCredentials([usernamePassword(credentialsId: accountId, passwordVariable: 'AWS_SECRET_ACCESS_KEY', usernameVariable: 'AWS_ACCESS_KEY_ID')]) {
            container('devops') {
              sh "make AMI_REGIONS=${config.regions} kubernetes_version=${KUBERNETES_VERSION} OG_IMAGE_VERSION=${OG_IMAGE_VERSION} k8s"
            } // container
          }// withCredentials
        }
      }

      [accountId, job]
    } // jobs

    parallel jobs

    archiveArtifacts(artifacts: PACKER_IMAGE_MANIFEST, fingerprint: true)
  } // stage('Bake Encrypted AMIs')
}
