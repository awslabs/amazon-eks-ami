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
    ap-east-2)
      acct="533267051163"
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
    us-iso-west-1)
      acct="608367168043"
      ;;
    us-iso-east-1)
      acct="725322719131"
      ;;
    us-isob-east-1)
      acct="187977181151"
      ;;
    eu-isoe-west-1)
      acct="249663109785"
      ;;
    us-isof-south-1)
      acct="676585237158"
      ;;
    af-south-1)
      acct="877085696533"
      ;;
    ap-southeast-3)
      acct="296578399912"
      ;;
    me-central-1)
      acct="759879836304"
      ;;
    eu-south-1)
      acct="590381155156"
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
    ca-west-1)
      acct="761377655185"
      ;;
    ap-southeast-5)
      acct="151610086707"
      ;;
    ap-southeast-6)
      acct="333609536671"
      ;;
    ap-southeast-7)
      acct="121268973566"
      ;;
    mx-central-1)
      acct="730335286997"
      ;;
    # This sections includes all commercial non-opt-in regions, which use
    # the same account for ECR pause container images, but still have in-region
    # registries.
    ap-northeast-1 | \
      ap-northeast-2 | \
      ap-northeast-3 | \
      ap-south-1 | \
      ap-southeast-1 | \
      ap-southeast-2 | \
      ca-central-1 | \
      eu-central-1 | \
      eu-north-1 | \
      eu-west-1 | \
      eu-west-2 | \
      eu-west-3 | \
      sa-east-1 | \
      us-east-1 | \
      us-east-2 | \
      us-west-1 | \
      us-west-2)
      acct="602401143452"
      ;;
    # If the region is not mapped to an account, let's try to choose another region
    # in that partition.
    us-gov-*)
      acct="013241004608"
      region="us-gov-west-1"
      ;;
    cn-*)
      acct="961992271922"
      region="cn-northwest-1"
      ;;
    us-iso-*)
      acct="725322719131"
      region="us-iso-east-1"
      ;;
    us-isob-*)
      acct="187977181151"
      region="us-isob-east-1"
      ;;
    eu-isoe-*)
      acct="249663109785"
      region="eu-isoe-west-1"
      ;;
    us-isof-*)
      acct="676585237158"
      region="us-isof-south-1"
      ;;
    *)
      acct="602401143452"
      region="us-west-2"
      ;;
  esac # end region check
fi

ECR_DOMAIN="${acct}.dkr.ecr.${region}.${aws_domain}"

# if FIPS is enabled on the machine, use the FIPS endpoint if it's available
if [[ "$(sysctl -n crypto.fips_enabled)" == 1 ]]; then
  ECR_FIPS_DOMAIN="${acct}.dkr.ecr-fips.${region}.${aws_domain}"
  if [ $(getent hosts "$ECR_FIPS_DOMAIN" | wc -l) -gt 0 ]; then
    echo "$ECR_FIPS_DOMAIN"
    exit 0
  fi
fi

echo "$ECR_DOMAIN"
