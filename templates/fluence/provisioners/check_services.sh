#!/bin/bash

echo "Enable ssm-agent service"
sudo systemctl enable amazon-ssm-agent.service

echo "Check what services are enabled"
systemctl --type=service --no-pager --state=active
