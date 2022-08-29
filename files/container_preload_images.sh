#!/usr/bin/env bash

set -x

sudo systemctl start docker

# login to private docker registry before pulling
aws ecr get-login-password --region eu-central-1 | sudo docker login -u AWS --password-stdin 602401143452.dkr.ecr.eu-central-1.amazonaws.com 

# kubectl -n kube-system -o json get deployment coredns | jq -r '.spec.template.spec.containers[].image'
# kubectl -n ingress -o json get deployment traefik | jq -r '.spec.template.spec.containers[].image'
# kubectl get daemonset -o json --all-namespaces | jq -r '.items[].spec.template.spec.containers[].image' | sort
sudo docker pull public.ecr.aws/eks-distro/coredns/coredns:v1.8.7-eks-1-22-9
sudo docker pull public.ecr.aws/eks-distro/coredns/coredns:v1.8.7-eks-1-23-4
sudo docker pull ghcr.io/sylr/traefik:v2.8.3_sylr.1
sudo docker pull 602401143452.dkr.ecr.eu-central-1.amazonaws.com/eks/aws-ebs-csi-driver:v1.6.2
sudo docker pull public.ecr.aws/ebs-csi-driver/aws-ebs-csi-driver:v1.6.2
sudo docker pull k8s.gcr.io/sig-storage/csi-node-driver-registrar:v2.5.1
sudo docker pull k8s.gcr.io/sig-storage/livenessprobe:v2.5.0
sudo docker pull k8s.gcr.io/sig-storage/livenessprobe:  v2.6.0
sudo docker pull public.ecr.aws/aws-ec2/aws-node-termination-handler:v1.17.1
sudo docker pull public.ecr.aws/aws-observability/aws-for-fluent-bit:2.28.0
sudo docker pull quay.io/cilium/cilium:v1.11.8
sudo docker pull quay.io/cilium/cilium:v1.12.1
sudo docker pull quay.io/cilium/startup-script:62bfbe88c17778aad7bef9fa57ff9e2d4a9ba0d8
sudo docker pull quay.io/prometheus/node-exporter:v1.3.1

sudo systemctl restart docker
sleep 30
