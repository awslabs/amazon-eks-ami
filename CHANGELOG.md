# Changelog

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
