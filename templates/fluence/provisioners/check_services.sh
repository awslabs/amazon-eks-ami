#!/bin/bash

echo "Check what services are enabled"
systemctl --type=service --no-pager --state=active
