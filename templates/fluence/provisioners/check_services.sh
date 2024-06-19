#!/bin/bash

echo "Enable ssm-agent service"
#sudo systemctl enable amazon-ssm-agent

cat /usr/lib/systemd/system/amazon-ssm-agent.service

echo "Check ssm-agent service status"
sudo systemctl status amazon-ssm-agent

echo "Check what services are enabled"
systemctl --type=service --no-pager --state=active
