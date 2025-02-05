#!/usr/bin/env bash
set -o pipefail
set -o nounset
set -o errexit

if [ "$ENABLE_EFA" != "true" ]; then
  exit 0
fi

##########################################################################################
### Setup installer ######################################################################
### https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/efa-start.html#efa-start-enable ##
##########################################################################################
EFA_VERSION="latest"
EFA_PACKAGE="aws-efa-installer-${EFA_VERSION}.tar.gz"
EFA_DOMAIN="https://efa-installer.amazonaws.com"
PARTITION=$(imds "/latest/meta-data/services/partition")

if [ ${PARTITION} == "aws-iso" ]; then
  EFA_DOMAIN="https://aws-efa-installer.s3.${AWS_REGION}.c2s.ic.gov"
elif [ ${PARTITION} == "aws-iso-b" ]; then
  EFA_DOMAIN="https://aws-efa-installer.s3.${AWS_REGION}.sc2s.sgov.gov"
elif [ ${PARTITION} == "aws-iso-e" ]; then
  EFA_DOMAIN="https://aws-efa-installer.s3.${AWS_REGION}.cloud.adc-e.uk"
elif [ ${PARTITION} == "aws-iso-f" ]; then
  EFA_DOMAIN="https://aws-efa-installer.s3.${AWS_REGION}.csp.hci.ic.gov"
fi

mkdir -p /tmp/efa-installer
cd /tmp/efa-installer

#https://github.com/amazonlinux/amazon-linux-2023/issues/243
sudo dnf swap -y gnupg2-minimal gnupg2-full

##########################################################################################
### Download installer ###################################################################
##########################################################################################
if [ ${PARTITION} == "aws-iso-e" ]; then
  aws s3 cp --region ${BINARY_BUCKET_REGION} s3://${BINARY_BUCKET_NAME}/rpms/${EFA_PACKAGE} .
  aws s3 cp --region ${BINARY_BUCKET_REGION} s3://${BINARY_BUCKET_NAME}/rpms/aws-efa-installer.key . && gpg --import aws-efa-installer.key
  aws s3 cp --region ${BINARY_BUCKET_REGION} s3://${BINARY_BUCKET_NAME}/rpms/${EFA_PACKAGE}.sig .
else
  curl -O ${EFA_DOMAIN}/${EFA_PACKAGE}
  curl -O ${EFA_DOMAIN}/aws-efa-installer.key && gpg --import aws-efa-installer.key
  curl -O ${EFA_DOMAIN}/${EFA_PACKAGE}.sig
fi

if ! gpg --verify ./aws-efa-installer-${EFA_VERSION}.tar.gz.sig &> /dev/null; then
  echo "EFA Installer signature failed verification!"
  exit 2
fi

##########################################################################################
### Install and cleanup ##################################################################
##########################################################################################
tar -xf ${EFA_PACKAGE} && cd aws-efa-installer
sudo ./efa_installer.sh --minimal -y

cd -
sudo rm -rf /tmp/efa-installer
sudo dnf swap -y gnupg2-full gnupg2-minimal
