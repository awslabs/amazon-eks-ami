#!/bin/bash

cat /usr/lib/systemd/system/amazon-ssm-agent.service

echo "Check ssm-agent service status"
sudo systemctl status amazon-ssm-agent --no-pager

echo "Start ssm-agent service"
sudo systemctl start amazon-ssm-agent --no-pager

echo "Get ssm-agent logs"
sudo journalctl -u amazon-ssm-agent --no-pager

echo "Check what services are enabled"
systemctl --type=service --no-pager --state=active
