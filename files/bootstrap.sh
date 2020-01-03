#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -o errexit

err_report() {
    echo "Exited with error on line $1"
}
trap 'err_report $LINENO' ERR

IFS=$'\n\t'

function print_help {
    echo "usage: $0 [options] <cluster-name>"
    echo "Bootstraps an instance into an EKS cluster"
    echo ""
    echo "-h,--help print this help"
    echo "--use-max-pods Sets --max-pods for the kubelet when true. (default: true)"
    echo "--b64-cluster-ca The base64 encoded cluster CA content. Only valid when used with --apiserver-endpoint. Bypasses calling \"aws eks describe-cluster\""
    echo "--apiserver-endpoint The EKS cluster API Server endpoint. Only valid when used with --b64-cluster-ca. Bypasses calling \"aws eks describe-cluster\""
    echo "--kubelet-extra-args Extra arguments to add to the kubelet. Useful for adding labels or taints."
    echo "--enable-docker-bridge Restores the docker default bridge network. (default: false)"
    echo "--aws-api-retry-attempts Number of retry attempts for AWS API call (DescribeCluster) (default: 3)"
    echo "--docker-config-json The contents of the /etc/docker/daemon.json file. Useful if you want a custom config differing from the default one in the AMI"
}

POSITIONAL=()

while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -h|--help)
            print_help
            exit 1
            ;;
        --use-max-pods)
            USE_MAX_PODS="$2"
            shift
            shift
            ;;
        --b64-cluster-ca)
            B64_CLUSTER_CA=$2
            shift
            shift
            ;;
        --apiserver-endpoint)
            APISERVER_ENDPOINT=$2
            shift
            shift
            ;;
        --kubelet-extra-args)
            KUBELET_EXTRA_ARGS=$2
            shift
            shift
            ;;
        --enable-docker-bridge)
            ENABLE_DOCKER_BRIDGE=$2
            shift
            shift
            ;;
        --aws-api-retry-attempts)
            API_RETRY_ATTEMPTS=$2
            shift
            shift
            ;;
        --docker-config-json)
            DOCKER_CONFIG_JSON=$2
            shift
            shift
            ;;
        --pause-container-account)
            PAUSE_CONTAINER_ACCOUNT=$2
            shift
            shift
            ;;
        --pause-container-version)
            PAUSE_CONTAINER_VERSION=$2
            shift
            shift
            ;;
        *)    # unknown option
            POSITIONAL+=("$1") # save it in an array for later
            shift # past argument
            ;;
    esac
done

set +u
set -- "${POSITIONAL[@]}" # restore positional parameters
CLUSTER_NAME="$1"
set -u

USE_MAX_PODS="${USE_MAX_PODS:-true}"
B64_CLUSTER_CA="${B64_CLUSTER_CA:-}"
APISERVER_ENDPOINT="${APISERVER_ENDPOINT:-}"
KUBELET_EXTRA_ARGS="${KUBELET_EXTRA_ARGS:-}"
ENABLE_DOCKER_BRIDGE="${ENABLE_DOCKER_BRIDGE:-false}"
API_RETRY_ATTEMPTS="${API_RETRY_ATTEMPTS:-3}"
DOCKER_CONFIG_JSON="${DOCKER_CONFIG_JSON:-}"
PAUSE_CONTAINER_VERSION="${PAUSE_CONTAINER_VERSION:-3.1}"

function get_pause_container_account_for_region () {
    local region="$1"
    case "${region}" in
    ap-east-1)
        echo "${PAUSE_CONTAINER_ACCOUNT:-800184023465}";;
    me-south-1)
        echo "${PAUSE_CONTAINER_ACCOUNT:-558608220178}";;
    *)
        echo "${PAUSE_CONTAINER_ACCOUNT:-602401143452}";;
    esac
}

# Helper function which calculates the amount of the given resource (either CPU or memory)
# to reserve in a given resource range, specified by a start and end of the range and a percentage
# of the resource to reserve. Note that we return zero if the start of the resource range is
# greater than the total resource capacity on the node. Additionally, if the end range exceeds the total
# resource capacity of the node, we use the total resource capacity as the end of the range.
# Args:
#   $1 total available resource on the worker node in input unit (either millicores for CPU or Mi for memory)
#   $2 start of the resource range in input unit
#   $3 end of the resource range in input unit
#   $4 percentage of range to reserve in percent*100 (to allow for two decimal digits)
# Return:
#   amount of resource to reserve in input unit
get_resource_to_reserve_in_range() {
  local total_resource_on_instance=$1
  local start_range=$2
  local end_range=$3
  local percentage=$4
  resources_to_reserve="0"
  if (( $total_resource_on_instance > $start_range )); then
    resources_to_reserve=$(((($total_resource_on_instance < $end_range ? \
        $total_resource_on_instance : $end_range) - $start_range) * $percentage / 100 / 100))
  fi
  echo $resources_to_reserve
}

# Calculates the amount of memory to reserve for the kubelet in mebibytes from the total memory available on the instance.
# From the total memory capacity of this worker node, we calculate the memory resources to reserve
# by reserving a percentage of the memory in each range up to the total memory available on the instance.
# We are using these memory ranges from GKE (https://cloud.google.com/kubernetes-engine/docs/concepts/cluster-architecture#node_allocatable):
# 255 Mi of memory for machines with less than 1024Mi of memory
# 25% of the first 4096Mi of memory
# 20% of the next 4096Mi of memory (up to 8192Mi)
# 10% of the next 8192Mi of memory (up to 16384Mi)
# 6% of the next 114688Mi of memory (up to 131072Mi)
# 2% of any memory above 131072Mi
# Args:
#   $1 total available memory on the machine in Mi
# Return:
#   memory to reserve in Mi for the kubelet
get_memory_mebibytes_to_reserve() {
  local total_memory_on_instance=$1
  local memory_ranges=(0 4096 8192 16384 131072 $total_memory_on_instance)
  local memory_percentage_reserved_for_ranges=(2500 2000 1000 600 200)
  if (( $total_memory_on_instance <= 1024 )); then
    memory_to_reserve="255"
  else
    memory_to_reserve="0"
    for i in ${!memory_percentage_reserved_for_ranges[@]}; do
      local start_range=${memory_ranges[$i]}
      local end_range=${memory_ranges[(($i+1))]}
      local percentage_to_reserve_for_range=${memory_percentage_reserved_for_ranges[$i]}
      memory_to_reserve=$(($memory_to_reserve + \
          $(get_resource_to_reserve_in_range $total_memory_on_instance $start_range $end_range $percentage_to_reserve_for_range)))
    done
  fi
  echo $memory_to_reserve
}

# Calculates the amount of CPU to reserve for the kubelet in millicores from the total number of vCPUs available on the instance.
# From the total core capacity of this worker node, we calculate the CPU resources to reserve by reserving a percentage
# of the available cores in each range up to the total number of cores available on the instance.
# We are using these CPU ranges from GKE (https://cloud.google.com/kubernetes-engine/docs/concepts/cluster-architecture#node_allocatable):
# 6% of the first core
# 1% of the next core (up to 2 cores)
# 0.5% of the next 2 cores (up to 4 cores)
# 0.25% of any cores above 4 cores
# Args:
#   $1 total number of millicores on the instance (number of vCPUs * 1000)
# Return:
#   CPU resources to reserve in millicores (m)
get_cpu_millicores_to_reserve() {
  local total_cpu_on_instance=$1
  local cpu_ranges=(0 1000 2000 4000 $total_cpu_on_instance)
  local cpu_percentage_reserved_for_ranges=(600 100 50 25)
  cpu_to_reserve="0"
  for i in ${!cpu_percentage_reserved_for_ranges[@]}; do
    local start_range=${cpu_ranges[$i]}
    local end_range=${cpu_ranges[(($i+1))]}
    local percentage_to_reserve_for_range=${cpu_percentage_reserved_for_ranges[$i]}
    cpu_to_reserve=$(($cpu_to_reserve + \
        $(get_resource_to_reserve_in_range $total_cpu_on_instance $start_range $end_range $percentage_to_reserve_for_range)))
  done
  echo $cpu_to_reserve
}

if [ -z "$CLUSTER_NAME" ]; then
    echo "CLUSTER_NAME is not defined"
    exit  1
fi

ZONE=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
AWS_DEFAULT_REGION=$(echo $ZONE | awk '{print substr($0, 1, length($0)-1)}')

MACHINE=$(uname -m)
if [ "$MACHINE" == "x86_64" ]; then
    ARCH="amd64"
elif [ "$MACHINE" == "aarch64" ]; then
    ARCH="arm64"
else
    echo "Unknown machine architecture '$MACHINE'" >&2
    exit 1
fi

PAUSE_CONTAINER_ACCOUNT=$(get_pause_container_account_for_region "${AWS_DEFAULT_REGION}")
PAUSE_CONTAINER_IMAGE=${PAUSE_CONTAINER_IMAGE:-$PAUSE_CONTAINER_ACCOUNT.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/eks/pause-${ARCH}}
PAUSE_CONTAINER="$PAUSE_CONTAINER_IMAGE:$PAUSE_CONTAINER_VERSION"

### kubelet kubeconfig

CA_CERTIFICATE_DIRECTORY=/etc/kubernetes/pki
CA_CERTIFICATE_FILE_PATH=$CA_CERTIFICATE_DIRECTORY/ca.crt
mkdir -p $CA_CERTIFICATE_DIRECTORY
if [[ -z "${B64_CLUSTER_CA}" ]] && [[ -z "${APISERVER_ENDPOINT}" ]]; then
    DESCRIBE_CLUSTER_RESULT="/tmp/describe_cluster_result.txt"
    rc=0
    # Retry the DescribleCluster API for API_RETRY_ATTEMPTS
    for attempt in `seq 0 $API_RETRY_ATTEMPTS`; do
        if [[ $attempt -gt 0 ]]; then
            echo "Attempt $attempt of $API_RETRY_ATTEMPTS"
        fi

        aws eks wait cluster-active \
            --region=${AWS_DEFAULT_REGION} \
            --name=${CLUSTER_NAME}

        aws eks describe-cluster \
            --region=${AWS_DEFAULT_REGION} \
            --name=${CLUSTER_NAME} \
            --output=text \
            --query 'cluster.{certificateAuthorityData: certificateAuthority.data, endpoint: endpoint}' > $DESCRIBE_CLUSTER_RESULT || rc=$?
        if [[ $rc -eq 0 ]]; then
            break
        fi
        if [[ $attempt -eq $API_RETRY_ATTEMPTS ]]; then
            exit $rc
        fi
        jitter=$((1 + RANDOM % 10))
        sleep_sec="$(( $(( 5 << $((1+$attempt)) )) + $jitter))"
        sleep $sleep_sec
    done
    B64_CLUSTER_CA=$(cat $DESCRIBE_CLUSTER_RESULT | awk '{print $1}')
    APISERVER_ENDPOINT=$(cat $DESCRIBE_CLUSTER_RESULT | awk '{print $2}')
fi

echo $B64_CLUSTER_CA | base64 -d > $CA_CERTIFICATE_FILE_PATH

sed -i s,CLUSTER_NAME,$CLUSTER_NAME,g /var/lib/kubelet/kubeconfig
sed -i s,MASTER_ENDPOINT,$APISERVER_ENDPOINT,g /var/lib/kubelet/kubeconfig
### kubelet.service configuration

MAC=$(curl -s http://169.254.169.254/latest/meta-data/network/interfaces/macs/ -s | head -n 1 | sed 's/\/$//')
TEN_RANGE=$(curl -s http://169.254.169.254/latest/meta-data/network/interfaces/macs/$MAC/vpc-ipv4-cidr-blocks | grep -c '^10\..*' || true )
DNS_CLUSTER_IP=10.100.0.10
if [[ "$TEN_RANGE" != "0" ]] ; then
    DNS_CLUSTER_IP=172.20.0.10;
fi

KUBELET_CONFIG=/etc/kubernetes/kubelet/kubelet-config.json
echo "$(jq ".clusterDNS=[\"$DNS_CLUSTER_IP\"]" $KUBELET_CONFIG)" > $KUBELET_CONFIG

# Sets kubeReserved and evictionHard in /etc/kubernetes/kubelet/kubelet-config.json for worker nodes. The following two function
# calls calculate the CPU and memory resources to reserve for the kubelet based on instance type of the worker node.
# Note that allocatable memory and CPU resources on worker nodes is calculated by the Kubernetes scheduler
# with this formula when scheduling pods: Allocatable = Capacity - Reserved - Eviction Threshold.

# gets the memory and CPU capacity of the worker node
MEMORY_MI=$(free -m | grep Mem | awk '{print $2}')
CPU_MILLICORES=$(($(nproc) * 1000))
# calculates the amount of each resource to reserve
mebibytes_to_reserve=$(get_memory_mebibytes_to_reserve $MEMORY_MI)
cpu_millicores_to_reserve=$(get_cpu_millicores_to_reserve $CPU_MILLICORES)
# writes kubeReserved and evictionHard to the kubelet-config using the amount of CPU and memory to be reserved
echo "$(jq '. += {"evictionHard": {"memory.available": "100Mi", "nodefs.available": "10%", "nodefs.inodesFree": "5%"}}' $KUBELET_CONFIG)" > $KUBELET_CONFIG
echo "$(jq --arg mebibytes_to_reserve "${mebibytes_to_reserve}Mi" --arg cpu_millicores_to_reserve "${cpu_millicores_to_reserve}m" \
    '. += {kubeReserved: {"cpu": $cpu_millicores_to_reserve, "ephemeral-storage": "1Gi", "memory": $mebibytes_to_reserve}}' $KUBELET_CONFIG)" > $KUBELET_CONFIG

INTERNAL_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
INSTANCE_TYPE=$(curl -s http://169.254.169.254/latest/meta-data/instance-type)

if [[ "$USE_MAX_PODS" = "true" ]]; then
    MAX_PODS_FILE="/etc/eks/eni-max-pods.txt"
    set +o pipefail
    MAX_PODS=$(grep ^$INSTANCE_TYPE $MAX_PODS_FILE | awk '{print $2}')
    set -o pipefail
    if [[ -n "$MAX_PODS" ]]; then
        echo "$(jq ".maxPods=$MAX_PODS" $KUBELET_CONFIG)" > $KUBELET_CONFIG
    else
        echo "No entry for $INSTANCE_TYPE in $MAX_PODS_FILE. Not setting max pods for kubelet"
    fi
fi

cat <<EOF > /etc/systemd/system/kubelet.service.d/10-kubelet-args.conf
[Service]
Environment='KUBELET_ARGS=--node-ip=$INTERNAL_IP --pod-infra-container-image=$PAUSE_CONTAINER'
EOF

if [[ -n "$KUBELET_EXTRA_ARGS" ]]; then
    cat <<EOF > /etc/systemd/system/kubelet.service.d/30-kubelet-extra-args.conf
[Service]
Environment='KUBELET_EXTRA_ARGS=$KUBELET_EXTRA_ARGS'
EOF
fi

# Replace with custom docker config contents.
if [[ -n "$DOCKER_CONFIG_JSON" ]]; then
    echo "$DOCKER_CONFIG_JSON" > /etc/docker/daemon.json
    systemctl restart docker
fi

if [[ "$ENABLE_DOCKER_BRIDGE" = "true" ]]; then
    # Enabling the docker bridge network. We have to disable live-restore as it
    # prevents docker from recreating the default bridge network on restart
    echo "$(jq '.bridge="docker0" | ."live-restore"=false' /etc/docker/daemon.json)" > /etc/docker/daemon.json
    systemctl restart docker
fi

systemctl daemon-reload
systemctl enable kubelet
systemctl start kubelet
