const github = require('@actions/github');

const allowlist = {
  users: [
    "cartermckinnon"
  ],
  teams: [
    "eks-node"
  ],
  orgs: [
    "awslabs"
  ]
};

export function isUserAllowed(user, ghclient) {
  if (allowlist.users.includes(user)) {
    return true;
  }
  const team = github;
  return false;
}