# Changelog

### amazon-eks-node-1.12-v20190329 | amazon-eks-node-1.11-v20190329 | amazon-eks-node-1.10-v20190329

Security Note: These AMIs contain builds of kubectl & CNI patched for [CVE-2019-1002101](https://aws.amazon.com/security/security-bulletins/AWS-2019-003/) and [CVE-2019-9946](https://aws.amazon.com/security/security-bulletins/AWS-2019-003/)

Note: This release publishes first set of worker AMIs for EKS 1.12 launch

* 77ae68a Correct version numbers in Changelog
* 3e09987 Bump CNI plugin default value
* fb0c393 Update eni-max-pods.txt (#231)
* a809997 Update README with new worker AMIs published on 2019-03-27
* a038aae Added 1.12 build in Makefile (#208)
* 38eb8a8 Fixed search for 10.x CIDR range
* 91ed091 Updated describe-cluster retry/backoff exponential with jitter
* 907df9f Updated the sleep time to seconds from milliseconds
* bc4216c Retry logic for describe cluster API call
* 325f1cc Fixed regex to match 10.x in all cases
* 7df0912 provide region during build
* 086c6a3 Ability to provide custom ami during build
* 6090f20 Updated binaries to latest releases
* 04c520d Create custom kubelet config with TTL-based secret-caching
* e5e5678 Fix downloading binaries from public s3 bucket.
* ae9b7d7 Fix: mac address is returned with trailing slash which breaks CIDR call resulting in false ten range
* 954d8b0 Allow pulling node binaries from private bucket (#175)
* 9f20002 Removed ulimit reduction
* a052b53 changed kube-proxy log rotation from create to copytruncate
* d2c26e8 Switched to RPM install for AWS CLI

### amazon-eks-node-1.11-v20190220 | amazon-eks-node-1.10-v20190220

* c1934bb Made docker install optional
* 0db49b4 Added enable-docker-bridge bootstrap argument
* 5a57ab8 Increase ulimits for docker containers.
* 4cf8ff5 Fix bug causing bootstrap.sh to fail for certain instance types
* 42dfbd7 update docker version to 18.06
* 9ac7eba Clean resolv.conf before snapshotting
* 665c29d Updated changelog to clarify CVE-2019-5736
* 71e5db6 Added security wording to issue templates

### amazon-eks-node-1.11-v20190211 | amazon-eks-node-1.10-v20190211

Security Note: This AMI contains a build of Docker 17.06 that is patched for [CVE-2019-5736](https://aws.amazon.com/security/security-bulletins/AWS-2019-002/)

* 71cd4b0 Updated max-pods for larger instance types
* 28845f9 Allow parallel image pulls
* 5cc7f41 Make it possible to set the DOCKER_VERSION and CNI_* that are used.
* dedf096 Enable live-restore capability in docker daemon
* bed1c54 Replace Path: "/"
* 10c5285 add spacing between remaining components
* 2c60058 remove superflous linebreaks
* e2f7dfa remove superflous lists
* 342e387 consolidate list indentation style
* 9856a22 ensure "Description" fields appear ealier in template
* 06630cf remove default Path
* 2823ba8 remove superflous quotes
* 310215e Property --cgroup-root was not specified
* 7d5a94b Set hairpin mode to "hairpin-veth"
* 5479e95 disable docker0 bridge as it is not used
* 491a913 add bip address from RFC5735 / RFC5737 This will reduce the number of possible conflicts to deploy on existing networks. https://tools.ietf.org/html/rfc5735 https://tools.ietf.org/html/rfc5737
* f8c117f Allow (optional) smaller EBS root volumes with container optimized AMI
* 7f6c8cb Remove trailing and leading lines.
* 01cfe98 Enable syncing of rtc clock in chronyd daemon.

### amazon-eks-node-1.11-v20190109 | amazon-eks-node-1.10-v20190109

* 208c114 Make bootstrap script more readable
* 44d18b7 Addresses #136 - set +e doesn't seem to work. Will return 0 or TEN_RANGE
* 8a1d7c0 Use chrony for time and make sure it is enabled on startup. (#130)
* b46b99a Only restart on failures
* e13d401 Update kubelet.service to be resilient to crashing
* 2f2401a Reversing order to make easier to read
* d1c3e0c Added 1.11 build in Makefile
* 9b8dc41 Fix rendering of the readme file
* 1797887 Update changelog and readme for 1.10 and 1.11 v20181210 worker nodes

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

<!-- git log --pretty=format:"* %h %s" $(git describe --abbrev=0 --tags)..HEAD -->
