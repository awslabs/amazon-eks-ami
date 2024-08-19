const github  = require('@actions/github');
const core    = require('@actions/core');
const token   = process.env.GITHUB_TOKEN;
const octokit = new github.getOctokit(token);
const context = github.context;
const { BedrockRuntimeClient, InvokeModelCommand } = require("@aws-sdk/client-bedrock-runtime");

(async () => {

  const author = payload.comment.user.login;
  const authorized = ["OWNER", "MEMBER"].includes(payload.comment.author_association);
  if (!authorized) {
    console.log(`Comment author is not authorized: ${author}`);
    return;
  }
  console.log(`Comment author is authorized: ${author}`);
  // Split the command into parts
  const parts = process.env.COMMENT_BODY.trim().split(' ');

  // Initialize the result object with default values
  let issueContext = {
    owner: parts.length == 4 ? parts[1] : context.repo.owner,
    repo: parts.length == 4 ? parts[2] : context.repo.repo,
    issue_number: parts.length == 4 ? parts[3] : ( parts.length == 2 ? parts[1] : context.issue.number),
  };

  console.log("Issue Context:\n" + JSON.stringify(issueContext));

  const { data: issue } = await octokit.rest.issues.get(issueContext);

  const { data: comments } = await octokit.rest.issues.listComments(issueContext);

  let commentLog = "Comment Log:\n";

  commentLog += `${issue.user.login} created the issue:\n "${issue.body}"\n`

  for (const comment of comments) {
    if(
      (comment.user.login != "github-actions[bot]") && 
      (!comment.body.startsWith("/"))
    ){
      commentLog += `${comment.user.login} says:\n"${comment.body}"\n`
    }
  }

  const client = new BedrockRuntimeClient({ region: process.env.AWS_REGION });

  const prompt = `Give me a short summary of this GitHub Issue reply chain. Include details on what the issue is, and what was the conclusion. The full comment history is below: ${commentLog}`;

  const messages = [
    {
      role: "user",
      content: []
    }
  ];
  messages[0].content.push({
    type: "text",
    text: `
      Human: ${prompt}
      Assistant:
    `
  });
  const payload = {
    anthropic_version: "bedrock-2023-05-31",
    max_tokens: 16384, // Adjust this if issue comment chain is long.
    messages: messages
  };

  const command = new InvokeModelCommand({
    contentType: "application/json",
    body: JSON.stringify(payload),
    modelId: process.env.MODEL_ID,
  });

  console.log("Prompting LLM with:\n" + JSON.stringify(payload));

  try {
    const response = await client.send(command);

    const responseBody = JSON.parse(new TextDecoder().decode(response.body));
    const generation = responseBody.content[0].text;
    //const generation = JSON.parse(responseBody).generation;

    console.log(`Raw response:\n${JSON.stringify(response)}`);
    console.log(`parsed response:\n${generation}`);

    await octokit.rest.issues.createComment({
      owner: context.repo.owner,
      repo: context.repo.repo,
      issue_number: context.issue.number,
      body: generation,
    });
    console.log("Finished!");
  } catch (error) {
    console.log(error)
    throw error;
  }
})();
