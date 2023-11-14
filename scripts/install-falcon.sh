#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -o errexit

validate_env_set AWS_ACCESS_KEY_ID
validate_env_set AWS_SECRET_ACCESS_KEY
validate_env_set AWS_SESSION_TOKEN

# download the rpm from s3 bucket
aws s3api get-object --bucket remote-dev-staging-falcon-rpm --key falcon-sensor-7.04.0-15907.amzn2.x86_64.rpm falcon-sensor.rpm

# Get the CID from the metadata
CID=$(aws s3api head-object --bucket remote-dev-staging-falcon-rpm --key falcon-sensor-7.04.0-15907.amzn2.x86_64.rpm --query 'Metadata.cid')

# Run the installer
sudo dpkg -i falcon-sensor.rpm

# Set CID on the sensor
sudo /opt/CrowdStrike/falconctl -s --cid=$CID

# Remove the host agent ID
sudo /opt/CrowdStrike/falconctl -d -f --aid

# Add the tag
sudo /opt/CrowdStrike/falconctl -s --tags="Crafting,EKS,Staging"