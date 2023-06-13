#!/usr/bin/env bash

if [ "${HACK}" = "true" ]; then
  # ideally we'll use the temporary SSH keypair that Packer creates, but AFAICT
  # this is the only way to access it at runtime -- it's only written to disk
  # in -debug mode, which is super clunky to use.
  echo "SSH private key: ${HACK_SSH_PRIVATE_KEY}" | tr -d '\n'
  echo "Joining Kubernetes cluster..."
  if sudo /etc/eks/bootstrap.sh ${HACK_BOOTSTRAP_ARGS}; then
    echo "Successfully bootstrapped!"
  else
    echo "Failed to bootstrap!"
  fi
  echo "(CTRL+C to wrap things up)"
  sleep 3600
fi
