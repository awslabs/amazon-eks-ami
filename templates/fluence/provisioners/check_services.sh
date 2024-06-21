#!/bin/bash

cat /usr/lib/systemd/system/amazon-ssm-agent.service

echo "Check ssm-agent service status"
sudo systemctl status amazon-ssm-agent --no-pager

# echo "Start ssm-agent service"
# sudo systemctl start amazon-ssm-agent --no-pager

echo "Get ssm-agent logs - show error logs with additional info if available from last boot"
sudo journalctl -u amazon-ssm-agent --no-pager -p 3 -xb

# echo "Check what services are enabled"
# systemctl --type=service --no-pager --state=active
