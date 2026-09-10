#!/usr/bin/env bash
# Build-time user data for the AL2027 AMI.
#
# The AL2027 minimal source AMIs do not ship amazon-ssm-agent.
# But Packer's ssh_interface=session_manager needs an SSM agent before it can open its tunnel, so install and start one here.
set -o errexit
set -o pipefail

dnf install -y amazon-ssm-agent
systemctl enable --now amazon-ssm-agent
