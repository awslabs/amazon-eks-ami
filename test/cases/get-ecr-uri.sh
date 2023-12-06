#!/usr/bin/env bash

set -o nounset
set -o errexit
set -o pipefail

echo "--> Should use specified account when passed in"
EXPECTED_ECR_URI="999999999999.dkr.ecr.mars-west-1.amazonaws.com.mars"
REGION="mars-west-1"
DOMAIN="amazonaws.com.mars"
ECR_URI=$(/etc/eks/get-ecr-uri.sh "${REGION}" "${DOMAIN}" "999999999999")
if [ ! "$ECR_URI" = "$EXPECTED_ECR_URI" ]; then
  echo "❌ Test Failed: expected ecr-uri=$EXPECTED_ECR_URI but got '${ECR_URI}'"
  exit 1
fi

echo "--> Should use account mapped to the region when set"
EXPECTED_ECR_URI="590381155156.dkr.ecr.eu-south-1.amazonaws.com"
REGION="eu-south-1"
DOMAIN="amazonaws.com"
ECR_URI=$(/etc/eks/get-ecr-uri.sh "${REGION}" "${DOMAIN}")
if [ ! "$ECR_URI" = "$EXPECTED_ECR_URI" ]; then
  echo "❌ Test Failed: expected ecr-uri=$EXPECTED_ECR_URI but got '${ECR_URI}'"
  exit 1
fi

echo "--> Should use non-opt-in account when not opt-in-region"
EXPECTED_ECR_URI="602401143452.dkr.ecr.us-east-2.amazonaws.com"
REGION="us-east-2"
DOMAIN="amazonaws.com"
ECR_URI=$(/etc/eks/get-ecr-uri.sh "${REGION}" "${DOMAIN}")
if [ ! "$ECR_URI" = "$EXPECTED_ECR_URI" ]; then
  echo "❌ Test Failed: expected ecr-uri=$EXPECTED_ECR_URI but got '${ECR_URI}'"
  exit 1
fi

echo "--> Should use us-west-2 account and region when opt-in-region"
EXPECTED_ECR_URI="602401143452.dkr.ecr.us-west-2.amazonaws.com"
REGION="eu-south-100"
DOMAIN="amazonaws.com"
ECR_URI=$(/etc/eks/get-ecr-uri.sh "${REGION}" "${DOMAIN}")
if [ ! "$ECR_URI" = "$EXPECTED_ECR_URI" ]; then
  echo "❌ Test Failed: expected ecr-uri=$EXPECTED_ECR_URI but got '${ECR_URI}'"
  exit 1
fi

echo "--> Should default us-gov-west-1 when unknown amazonaws.com.us-gov region"
EXPECTED_ECR_URI="013241004608.dkr.ecr.us-gov-west-1.amazonaws.com.us-gov"
REGION="us-gov-east-100"
DOMAIN="amazonaws.com.us-gov"
ECR_URI=$(/etc/eks/get-ecr-uri.sh "${REGION}" "${DOMAIN}")
if [ ! "$ECR_URI" = "$EXPECTED_ECR_URI" ]; then
  echo "❌ Test Failed: expected ecr-uri=$EXPECTED_ECR_URI but got '${ECR_URI}'"
  exit 1
fi

echo "--> Should default cn-northwest-1 when unknown amazonaws.com.cn region"
EXPECTED_ECR_URI="961992271922.dkr.ecr.cn-northwest-1.amazonaws.com.cn"
REGION="cn-north-100"
DOMAIN="amazonaws.com.cn"
ECR_URI=$(/etc/eks/get-ecr-uri.sh "${REGION}" "${DOMAIN}")
if [ ! "$ECR_URI" = "$EXPECTED_ECR_URI" ]; then
  echo "❌ Test Failed: expected ecr-uri=$EXPECTED_ECR_URI but got '${ECR_URI}'"
  exit 1
fi

echo "--> Should default us-iso-east-1 when unknown amazonaws.com.iso region"
EXPECTED_ECR_URI="725322719131.dkr.ecr.us-iso-east-1.amazonaws.com.iso"
REGION="us-iso-west-100"
DOMAIN="amazonaws.com.iso"
ECR_URI=$(/etc/eks/get-ecr-uri.sh "${REGION}" "${DOMAIN}")
if [ ! "$ECR_URI" = "$EXPECTED_ECR_URI" ]; then
  echo "❌ Test Failed: expected ecr-uri=$EXPECTED_ECR_URI but got '${ECR_URI}'"
  exit 1
fi

echo "--> Should default us-isob-east-1 when unknown amazonaws.com.isob region"
EXPECTED_ECR_URI="187977181151.dkr.ecr.us-isob-east-1.amazonaws.com.isob"
REGION="us-isob-west-100"
DOMAIN="amazonaws.com.isob"
ECR_URI=$(/etc/eks/get-ecr-uri.sh "${REGION}" "${DOMAIN}")
if [ ! "$ECR_URI" = "$EXPECTED_ECR_URI" ]; then
  echo "❌ Test Failed: expected ecr-uri=$EXPECTED_ECR_URI but got '${ECR_URI}'"
  exit 1
fi
