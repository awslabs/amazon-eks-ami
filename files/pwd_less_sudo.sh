#!/usr/bin/env bash
# make wheel pwd free
sudo sed -i '0,/%wheel[[:space:]]*ALL=(ALL)[[:space:]]*ALL/{s||%wheel        ALL=(ALL)       NOPASSWD: ALL|}' /etc/sudoers