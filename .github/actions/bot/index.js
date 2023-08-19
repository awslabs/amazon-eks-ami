const core = require('@actions/core');
const github = require('@actions/github');

const payload = github.context.payload;

if (!payload.pull_request || !payload.comment) {
    return;
}

const authorized = ["OWNER", "MEMBER"].find(payload.comment.author_association);
if (!authorized) {
    return;
}

const octokit = github.getOctokit(core.getInput('token'));

await octokit.rest.issues.createComment({
    owner: payload.repository.owner.login,
    repo: payload.repository.name,
    issue_number: payload.issue.number,
    body: `Hello ${payload.comment.user.login}!`
});
