#!/usr/bin/env bash

echo >&2 '
!!!!!!!!!!
!!!!!!!!!! ERROR: bootstrap.sh has been removed from AL2023-based EKS AMIs.
!!!!!!!!!!
!!!!!!!!!! EKS nodes are now initialized by nodeadm.
!!!!!!!!!!
!!!!!!!!!! To migrate your user data, see:
!!!!!!!!!!
!!!!!!!!!!     https://awslabs.github.io/amazon-eks-ami/nodeadm/
!!!!!!!!!!
'

exit 1
