#!/usr/bin/env groovy

/**
* Kubernetes deployment pipeline via Helm.
*
**/

// Load the OG Jenkins Library
@Library('OGJenkinsLib@3.6.1') _
import com.opengov.OGConstants
def nonce = new Random().nextInt(10000)
def date = new Date().format('yyyy-MM-dd', TimeZone.getTimeZone('PST'))

final GIT_REPOSITORY_NAME = 'amazon-eks-ami'
final String DEFAULT_UPLOAD_REGION = 'us-west-2'
final String AMI_NAME = "amazon-eks-encrypted-${date}-${nonce}"
final String ENCRYPTED = "true"
def config = [:]  // Pipeline configuration

def containers = [
  OGContainer('packer', 'hashicorp/packer', '1.4.1', [resourceLimitCpu: '2', resourceLimitMemory: '1G'])
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
    
    // Load the pipeline properties and configuration
    
    config.packerConf = utils.parseJSON(readFile('eks-worker-al2.json'))

    // Check version
    container('packer') {
      sh 'packer version'
      sh 'apk add --no-cache build-base python py-pip'
      sh 'pip install --upgrade awscli'

    }

    // Save the configuration as an artifact
    utils.createArtifact('initialConfig', config)
  }

  stage('Create and Push Encrypted AMIs') {
    container('packer') { 
        def jobs = config.accountIds.collect { accountId ->
          [accountId,
            {
              withCredentials([usernamePassword(credentialsId: accountId, passwordVariable: 'AWS_SECRET_ACCESS_KEY', usernameVariable: 'AWS_ACCESS_KEY_ID')]) {

                if (config.dry) {
                  echo "Would have ran: 'make VERSION=1.12.7 k8s'"
                } else {
                  sh 'make VERSION=1.12.7 k8s'
                }
              }
            }
          ]
        }.collectEntries()

        parallel jobs

        archiveArtifacts(artifacts:'manifest.json', fingerprint:true)
      
    }
  }
}