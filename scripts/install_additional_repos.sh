#!/usr/bin/env bash
#
# Install additional YUM repositories, typically used for security patches.
# The format of ADDITIONAL_YUM_REPOS is: "repo=patches-repo,name=Install patches,baseurl=http://amazonlinux.$awsregion.$awsdomain/xxxx,priority=10"
# which will create the file '/etc/yum.repos.d/patches-repo.repo' having the following content:
# ```
# [patches-repo]
# name=Install patches
# baseurl=http://amazonlinux.$awsregion.$awsdomain/xxxx
# priority=10
# ```
# Note that priority is optional, but the other parameters are required. Multiple yum repos can be specified, each one separated by ';'

if [ -z "${ADDITIONAL_YUM_REPOS}" ]; then
  echo "no additional yum repo, skipping"
  exit 0
fi


AWK_CMD='
BEGIN {RS=";";FS=","}
{
  delete vars; 
  for(i = 1; i <= NF; ++i) { 
    n = index($i, "="); 
    if(n) { 
      vars[substr($i, 1, n-1)] = substr($i, n + 1)
    }
  } 
  Repo = "/etc/yum.repos.d/"vars["repo"]".repo"
}
{print "["vars["repo"]"]" > Repo}
{print "name="vars["name"] > Repo}
{print "baseurl="vars["baseurl"] > Repo}
{if (length(vars["priority"]) != 0) print "priority="vars["priority"] > Repo}
'
sudo awk "$AWK_CMD" <<< "${ADDITIONAL_YUM_REPOS}"