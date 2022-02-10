#!/usr/bin/env bash
SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
set -euo pipefail

docker build -t eks-optimized-ami -f "${SCRIPTPATH}/Dockerfile" "${SCRIPTPATH}/../"

summary=""
status=0

function run(){
    local exit_code=0
    ## expectation status code
    local expectation=$1
    shift
    ## test name for output
    local name=$1
    shift
    echo "#########################################################################################################"
    echo "$@"
    echo "---------------------------------------------STDOUT------------------------------------------------------"
    docker run -v ${PWD}/../files/bootstrap.sh:/etc/eks/bootstrap.sh \
        -v ${PWD}/../files/max-pods-calculator.sh:/etc/eks/max-pods-calculator.sh \
        -it eks-optimized-ami $@ || exit_code=$?
    if [[ ${exit_code} -eq ${expectation} ]]; then
        msg="✅ Test \"${name}\" Passed"
    else
        msg="❌ Test \"${name}\" Failed"
        status=1
    fi
    summary+="${msg}\n"
    echo "${msg}"
    echo -e "#########################################################################################################\n\n"
}

run 0 "Default params should pass" /etc/eks/bootstrap.sh \
    --b64-cluster-ca dGVzdA== \
    --apiserver-endpoint http://my-api-endpoint \
    test

run 1 "Should fail w/ \"service-ipv6-cidr must be provided when ip-family is specified as ipv6\"" /etc/eks/bootstrap.sh \
    --b64-cluster-ca dGVzdA== \
    --apiserver-endpoint http://my-api-endpoint \
    --ip-family ipv6 \
    test
  
run 0 "Should return IPv6 DNS cluster IP when given service-ipv6-cidr" /etc/eks/bootstrap.sh \
    --b64-cluster-ca dGVzdA== \
    --apiserver-endpoint http://my-api-endpoint \
    --ip-family ipv6 \
    --service-ipv6-cidr fe80::1 \
    test

run 0 "Should return ipv6 DNS Cluster IP when given dns-cluster-ip" /etc/eks/bootstrap.sh \
    --b64-cluster-ca dGVzdA== \
    --apiserver-endpoint http://my-api-endpoint \
    --ip-family ipv6 \
    --dns-cluster-ip fe80::1 \
    test

run 0 "Should return IPv4 DNS Cluster IP when given dns-cluster-ip" /etc/eks/bootstrap.sh \
    --b64-cluster-ca dGVzdA== \
    --apiserver-endpoint http://my-api-endpoint \
    --ip-family ipv4 \
    --dns-cluster-ip 192.168.0.1 \
    test

run 1 "Should fail validation - ip-family mismatch" /etc/eks/bootstrap.sh \
    --b64-cluster-ca dGVzdA== \
    --apiserver-endpoint http://my-api-endpoint \
    --ip-family ipv4 \
    --service-ipv6-cidr 192.168.0.1/24 \
    test

run 0 "Should calc max-pods successfully" /etc/eks/max-pods-calculator.sh \
    --instance-type-from-imds \
    --cni-version 1.7.5

echo -e "\n\n"
echo "==================================================================================================================="
echo -e "Test Summary:"
echo "==================================================================================================================="
echo -e "${summary}"
exit $status
