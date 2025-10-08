#!/usr/bin/env bash
set -euo pipefail

echo "-> Should handle duplicate --max-pods arguments in KUBELET_EXTRA_ARGS"
exit_code=0
/etc/eks/bootstrap.sh \
  --b64-cluster-ca dGVzdA== \
  --apiserver-endpoint http://my-api-endpoint \
  --kubelet-extra-args '--node-labels=test=duplicate --max-pods=58 --max-pods=30' \
  ipv4-cluster || exit_code=$?

if [[ ${exit_code} -ne 0 ]]; then
  echo "❌ Test Failed: expected a zero exit code but got '${exit_code}'"
  exit 1
fi

KUBELET_EXTRA_ARGS_FILE=/etc/systemd/system/kubelet.service.d/30-kubelet-extra-args.conf
if [[ ! -f ${KUBELET_EXTRA_ARGS_FILE} ]]; then
  echo "❌ Test Failed: ${KUBELET_EXTRA_ARGS_FILE} does not exist"
  exit 1
fi

MAX_PODS_COUNT=$(grep -oE -- '--max-pods=[0-9]+' ${KUBELET_EXTRA_ARGS_FILE} | wc -l)
if [[ ${MAX_PODS_COUNT} -ne 1 ]]; then
  echo "❌ Test Failed: expected exactly 1 --max-pods argument but found ${MAX_PODS_COUNT}. Found: $(cat ${KUBELET_EXTRA_ARGS_FILE})"
  exit 1
fi

if ! grep -q -- '--max-pods=30' ${KUBELET_EXTRA_ARGS_FILE}; then
  echo "❌ Test Failed: expected --max-pods=30 (the last value) but not found. Found: $(cat ${KUBELET_EXTRA_ARGS_FILE})"
  exit 1
fi

if ! grep -q -- '--node-labels=test=duplicate' ${KUBELET_EXTRA_ARGS_FILE}; then
  echo "❌ Test Failed: expected --node-labels=test=duplicate to be preserved. Found: $(cat ${KUBELET_EXTRA_ARGS_FILE})"
  exit 1
fi

echo "-> Should handle no --max-pods argument"
exit_code=0
/etc/eks/bootstrap.sh \
  --b64-cluster-ca dGVzdA== \
  --apiserver-endpoint http://my-api-endpoint \
  --kubelet-extra-args '--node-labels=test=no-max-pods' \
  ipv4-cluster || exit_code=$?

if [[ ${exit_code} -ne 0 ]]; then
  echo "❌ Test Failed: expected a zero exit code but got '${exit_code}'"
  exit 1
fi

KUBELET_EXTRA_ARGS_FILE=/etc/systemd/system/kubelet.service.d/30-kubelet-extra-args.conf
if [[ ! -f ${KUBELET_EXTRA_ARGS_FILE} ]]; then
  echo "❌ Test Failed: ${KUBELET_EXTRA_ARGS_FILE} does not exist"
  exit 1
fi

MAX_PODS_COUNT=$(grep -oE -- '--max-pods=[0-9]+' ${KUBELET_EXTRA_ARGS_FILE} | wc -l || true)
if [[ ${MAX_PODS_COUNT} -ne 0 ]]; then
  echo "❌ Test Failed: expected no --max-pods argument but found ${MAX_PODS_COUNT}. Found: $(cat ${KUBELET_EXTRA_ARGS_FILE})"
  exit 1
fi

if ! grep -q -- '--node-labels=test=no-max-pods' ${KUBELET_EXTRA_ARGS_FILE}; then
  echo "❌ Test Failed: expected --node-labels=test=no-max-pods to be preserved. Found: $(cat ${KUBELET_EXTRA_ARGS_FILE})"
  exit 1
fi
