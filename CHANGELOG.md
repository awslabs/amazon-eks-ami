# Changelog

### amazon-eks-node-1.11-v20181210 | amazon-eks-node-1.10-v20181210
* 87a2aec Added GitHub issue templates
* 95138f1 Simplified ASG Update parameters
* 31f7d62 Swap order of `sed` and `kubectl config`
* 9ad6e2a Add back the allow-privileged kubelet flag
* 0bf1109 Added serverTLSBootstrap to kubelet config file
* a5492b2 Added node ASG update policy parameters
* b7015a6 Remove deprecated flags that use default values
* d5a6437 Docker config should be owned by root
* c281f32 Adding mkdir command
* 90c5eae Adding simple dockerd config file to rotate logs from containers
* 01090f8 Gracefully handle unknown instance types
* 68e7a62 Added AMI metadata file
* c0110a7 Reverted max-pod updates and instance types
* 90d5209 Correctly select kube-DNS address for secondary CIDR VPC instances
* f7b7f6c Updated kubelet config file location
* 8ff10f2 Updated instance types and eni counts
* 67053cf Modifying kubelet to use config files instead of kubelet flags which are about to deprecate. (#90)
* 6a20fb1 Add max pods information for g3s.xlarge instances
* a16af46 kubelet config files should be owned by root
* f27bc2e Update eni-max-pods.txt

### amazon-eks-node-v25
* 45a12de Fix kube-proxy logrotate (#68)
* 742df5e Change make targets to be .PHONY (#59)
* eb0239f Add NodeSecurityGroup to outputs. (#58)
* 7219545 Only add max-pods for a known instance type (#57)

Note: CNI >= 1.2.1 is required for t3 and r5 instance support.

### amazon-eks-node-v24

* 9cda183 Scrub temporary build-time keypair (#48)
* 9578a45 remove packer key before shutdown (#43)
* cb86cc4 Move source_ami_filter owner to owners (#44)
* 4edeb0c Added /var/log/journal to build  (#40)
* 624bac1 Add support for KMS encryption - disabled by default (#33)
* 586cac2 Add validation for CNI and CNI Plugins downloads - fixes #37 (#38)
* 30617f4 Added back previous CloudFormation version in table (#35)
* b2f9656 Allow communication on TCP:443 from EKS Cluster to Worker nodes (#34)
* 72184ce Adding support New instance types (#31)
* 614d48c Added changelog for 8-21-18 release (#24)

### amazon-eks-node-v23

* ddaaa79 Add ability to modify node root volume size (#20)
* 0c7bd35 Added bootstrap args as a CloudFormation parameter (#23)
* 9736e73 Make sure ntp is installed and enabled (#18)
* 5ef02c9 Updated EKS AMI with bootstrap script (#16)

### eks-worker-v22

* Foreshadow update https://alas.aws.amazon.com/AL2/ALAS-2018-1058.html

### eks-worker-v21

* SegmentSmack update https://alas.aws.amazon.com/AL2/ALAS-2018-1050.html

### eks-worker-v20

* EKS Launch AMI

<!-- git log --pretty=format:"* %h %s" -->
