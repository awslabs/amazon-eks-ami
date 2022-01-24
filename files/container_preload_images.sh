#!/usr/bin/env bash

set -x

sudo systemctl start docker

# login to private docker registry before pulling
aws ecr get-login-password --region eu-central-1 | sudo docker login -u AWS --password-stdin 602401143452.dkr.ecr.eu-central-1.amazonaws.com 

# kubectl get daemonset -o json --all-namespaces | jq -r '.items[].spec.template.spec.containers[].image' | sort
sudo docker pull public.ecr.aws/eks-distro/coredns/coredns:v1.8.4-eks-1-21-7
sudo docker pull 602401143452.dkr.ecr.eu-central-1.amazonaws.com/eks/aws-ebs-csi-driver:v1.5.0
sudo docker pull k8s.gcr.io/sig-storage/csi-node-driver-registrar:v2.1.0
sudo docker pull k8s.gcr.io/sig-storage/livenessprobe:v2.2.0
sudo docker pull public.ecr.aws/aws-ec2/aws-node-termination-handler:v1.13.3
sudo docker pull public.ecr.aws/aws-observability/aws-for-fluent-bit:2.21.4
sudo docker pull quay.io/cilium/cilium:v1.10.6
sudo docker pull quay.io/cilium/cilium:v1.11.1
sudo docker pull quay.io/cilium/startup-script:62bfbe88c17778aad7bef9fa57ff9e2d4a9ba0d8
sudo docker pull quay.io/prometheus/node-exporter:v1.3.1
