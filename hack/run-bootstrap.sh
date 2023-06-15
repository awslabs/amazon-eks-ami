#!/usr/bin/env bash

if [ "${HACK}" = "true" ]; then
  echo "Bootstrapping..."
  if sudo /etc/eks/bootstrap.sh ${HACK_BOOTSTRAP_ARGS}; then
    echo "Successfully bootstrapped!"
  else
    echo "Failed to bootstrap!"
  fi
  echo "Starting SSM agent..."
  sudo systemctl start amazon-ssm-agent
  echo "SSM agent started! Connect to the instance like:"
  echo
  echo "aws ssm start-session --target $(imds /latest/meta-data/instance-id)"
  echo
  echo "Use CTRL+C to wrap things up."
  sleep 3600
fi
