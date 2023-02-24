#!/usr/bin/env bash
set -euo pipefail

# More details about the mappings in this file can be found here https://docs.aws.amazon.com/eks/latest/userguide/add-ons-images.html

region=$1
aws_domain=$2
if [[ $# -eq 3 ]] && [[ ! -z $3 ]]; then
  acct=$3
else
  case "${region}" in
    ap-east-1)
      acct="800184023465"
      ;;
    me-south-1)
      acct="558608220178"
      ;;
    cn-north-1)
      acct="918309763551"
      ;;
    cn-northwest-1)
      acct="961992271922"
      ;;
    us-gov-west-1)
      acct="013241004608"
      ;;
    us-gov-east-1)
      acct="151742754352"
      ;;
    us-iso-east-1)
      acct="725322719131"
      ;;
    us-isob-east-1)
      acct="187977181151"
      ;;
    af-south-1)
      acct="877085696533"
      ;;
    eu-south-1)
      acct="590381155156"
      ;;
    ap-southeast-3)
      acct="296578399912"
      ;;
    me-central-1)
      acct="759879836304"
      ;;
    eu-south-2)
      acct="455263428931"
      ;;
    eu-central-2)
      acct="900612956339"
      ;;
    ap-south-2)
      acct="900889452093"
      ;;
    ap-southeast-4)
      acct="491585149902"
      ;;
    il-central-1)
      acct="066635153087"
      ;;
    *)
      acct="602401143452"
      ;;
  esac
fi

echo "${acct}.dkr.ecr.${region}.${aws_domain}"
