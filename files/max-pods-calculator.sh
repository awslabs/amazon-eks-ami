#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -o errexit

err_report() {
  echo "Exited with error on line $1"
}
trap 'err_report $LINENO' ERR

function print_help {
  echo "usage: $0 <instance(s)> [options]"
  echo "Calculates maxPods value to be used when starting up the kubelet."
  echo "-h,--help print this help."
  echo "--instance-type Specify the instance type to calculate max pods value."
  echo "--instance-type-from-imds Use this flag if the instance type should be fetched from IMDS."
  echo "--cni-version Specify the version of the CNI (example - 1.7.5)."
  echo "--cni-custom-networking-enabled Use this flag to indicate if CNI custom networking mode has been enabled."
  echo "--cni-prefix-delegation-enabled Use this flag to indicate if CNI prefix delegation has been enabled."
  echo "--cni-max-eni specify how many ENIs should be used for prefix delegation. Defaults to using all ENIs per instance."
  echo "--show-max-allowed Use this flag to show max number of Pods allowed to run in Worker Node. Otherwise the script will show the recommended value"
}

POSITIONAL=()

while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -h | --help)
      print_help
      exit 1
      ;;
    --instance-type)
      INSTANCE_TYPE=$2
      shift
      shift
      ;;
    --instance-type-from-imds)
      INSTANCE_TYPE_FROM_IMDS=true
      shift
      ;;
    --cni-version)
      CNI_VERSION=$2
      shift
      shift
      ;;
    --cni-custom-networking-enabled)
      CNI_CUSTOM_NETWORKING_ENABLED=true
      shift
      ;;
    --cni-prefix-delegation-enabled)
      CNI_PREFIX_DELEGATION_ENABLED=true
      shift
      ;;
    --cni-max-eni)
      CNI_MAX_ENI=$2
      shift
      shift
      ;;
    --show-max-allowed)
      SHOW_MAX_ALLOWED=true
      shift
      ;;
    *)                   # unknown option
      POSITIONAL+=("$1") # save it in an array for later
      shift              # past argument
      ;;
  esac
done

CNI_VERSION="${CNI_VERSION:-}"
CNI_CUSTOM_NETWORKING_ENABLED="${CNI_CUSTOM_NETWORKING_ENABLED:-false}"
CNI_PREFIX_DELEGATION_ENABLED="${CNI_PREFIX_DELEGATION_ENABLED:-false}"
CNI_MAX_ENI="${CNI_MAX_ENI:-}"
INSTANCE_TYPE="${INSTANCE_TYPE:-}"
INSTANCE_TYPE_FROM_IMDS="${INSTANCE_TYPE_FROM_IMDS:-false}"
SHOW_MAX_ALLOWED="${SHOW_MAX_ALLOWED:-false}"

PREFIX_DELEGATION_SUPPORTED=false
IPS_PER_PREFIX=16

if [ "$INSTANCE_TYPE_FROM_IMDS" = true ]; then
  export AWS_DEFAULT_REGION=$(imds /latest/dynamic/instance-identity/document | jq .region -r)
  INSTANCE_TYPE=$(imds /latest/meta-data/instance-type)
elif [ -z "$INSTANCE_TYPE" ]; then # There's no reasonable default for an instanceType so force one to be provided to the script.
  echo "You must specify an instance type to calculate max pods value."
  exit 1
fi

if [ -z "$CNI_VERSION" ]; then
  echo "You must specify a CNI Version to use. Example - 1.7.5"
  exit 1
fi

calculate_max_ip_addresses_prefix_delegation() {
  enis=$1
  instance_max_eni_ips=$2
  echo $(($enis * (($instance_max_eni_ips - 1) * $IPS_PER_PREFIX) + 2))
}

calculate_max_ip_addresses_secondary_ips() {
  enis=$1
  instance_max_eni_ips=$2
  echo $(($enis * ($instance_max_eni_ips - 1) + 2))
}

min_number() {
  printf "%s\n" "$@" | sort -g | head -n1
}

VERSION_SPLIT=(${CNI_VERSION//./ })
CNI_MAJOR_VERSION="${VERSION_SPLIT[0]}"
CNI_MINOR_VERSION="${VERSION_SPLIT[1]}"
if [[ "$CNI_MAJOR_VERSION" -gt 1 ]] || ([[ "$CNI_MAJOR_VERSION" = 1 ]] && [[ "$CNI_MINOR_VERSION" -gt 8 ]]); then
  PREFIX_DELEGATION_SUPPORTED=true
fi

DESCRIBE_INSTANCES_RESULT=$(aws ec2 describe-instance-types --instance-type "${INSTANCE_TYPE}" --query 'InstanceTypes[0].{Hypervisor: Hypervisor, EniCount: NetworkInfo.MaximumNetworkInterfaces, PodsPerEniCount: NetworkInfo.Ipv4AddressesPerInterface, CpuCount: VCpuInfo.DefaultVCpus}' --output json)

HYPERVISOR_TYPE=$(echo $DESCRIBE_INSTANCES_RESULT | jq -r '.Hypervisor')
IS_NITRO=false
if [[ "$HYPERVISOR_TYPE" == "nitro" ]]; then
  IS_NITRO=true
fi
INSTANCE_MAX_ENIS=$(echo $DESCRIBE_INSTANCES_RESULT | jq -r '.EniCount')
INSTANCE_MAX_ENIS_IPS=$(echo $DESCRIBE_INSTANCES_RESULT | jq -r '.PodsPerEniCount')

if [ -z "$CNI_MAX_ENI" ]; then
  enis_for_pods=$INSTANCE_MAX_ENIS
else
  enis_for_pods="$(min_number $CNI_MAX_ENI $INSTANCE_MAX_ENIS)"
fi

if [ "$CNI_CUSTOM_NETWORKING_ENABLED" = true ]; then
  enis_for_pods=$((enis_for_pods - 1))
fi

if [ "$IS_NITRO" = true ] && [ "$CNI_PREFIX_DELEGATION_ENABLED" = true ] && [ "$PREFIX_DELEGATION_SUPPORTED" = true ]; then
  max_pods=$(calculate_max_ip_addresses_prefix_delegation $enis_for_pods $INSTANCE_MAX_ENIS_IPS)
else
  max_pods=$(calculate_max_ip_addresses_secondary_ips $enis_for_pods $INSTANCE_MAX_ENIS_IPS)
fi

# Limit the total number of pods that can be launched on any instance type based on the vCPUs on that instance type.
MAX_POD_CEILING_FOR_LOW_CPU=110
MAX_POD_CEILING_FOR_HIGH_CPU=250
CPU_COUNT=$(echo $DESCRIBE_INSTANCES_RESULT | jq -r '.CpuCount')

if [ "$SHOW_MAX_ALLOWED" = true ]; then
  echo $max_pods
  exit 0
fi

if [ "$CPU_COUNT" -gt 30 ]; then
  echo $(min_number $MAX_POD_CEILING_FOR_HIGH_CPU $max_pods)
else
  echo $(min_number $MAX_POD_CEILING_FOR_LOW_CPU $max_pods)
fi
