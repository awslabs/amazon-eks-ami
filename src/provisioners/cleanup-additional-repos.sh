#!/usr/bin/env bash
#
# Clean up additional YUM repositories, typically used for security patches.
# The format of ADDITIONAL_YUM_REPOS is: "repo=patches-repo,name=Install patches,baseurl=http://amazonlinux.$awsregion.$awsdomain/xxxx,priority=10"
# Multiple yum repos can be specified, separated by ';'

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
{cmd="rm -f " Repo; system(cmd)}
'
sudo awk "$AWK_CMD" <<< "${ADDITIONAL_YUM_REPOS}"
