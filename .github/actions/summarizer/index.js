const github  = require('@actions/github');
const core    = require('@actions/core');
const token   = process.env.GITHUB_TOKEN;
const octokit = new github.getOctokit(token);
const { BedrockRuntimeClient, InvokeModelCommand } = require("@aws-sdk/client-bedrock-runtime");

(async () => {
  const context = github.context;
  const payload = context.payload;
  const author = payload.comment.user.login;
  const authorized = ["OWNER", "MEMBER"].includes(payload.comment.author_association);
  // Ensure that invoker is either a Owner or member of awslabs / amazon-eks-ami
  if (!authorized) {
    console.log(`Comment author is not authorized: ${author}`);
    return;
  }
  console.log(`Comment author is authorized: ${author}`);

  // Split the command into parts
  const parts = process.env.COMMENT_BODY.trim().split(' ');

  // Commands can take three forms:
  // /summarize owner repo issue_no (length 4)
  // /summarize issue_no (length 2) (defaults owner & repo to context based)
  // /summarize (default) (defaults owner, repo, & issue_no to context based)
  let issueContext = {
    owner: parts.length == 4 ? parts[1] : context.repo.owner,
    repo: parts.length == 4 ? parts[2] : context.repo.repo,
    issue_number: parts.length == 4 ? parts[3] : ( parts.length == 2 ? parts[1] : context.issue.number),
  };

  console.log("Issue Context:\n" + JSON.stringify(issueContext));

  const { data: issue } = await octokit.rest.issues.get(issueContext);

  const { data: comments } = await octokit.rest.issues.listComments(issueContext);

  const commentLog = "Comment Log:\n" + 
    `${issue.user.login} created the issue:\n ${issue.body}\n` + 
    comments.filter(c => c.user.login != "github-actions[bot]")
      .filter(c -> !c.body.startsWith("/"))
      .map(c => `${c.user.login} says:\n "${c.body}"`)
      .join('\n');

  //let commentLog = "Comment Log:\n";
  //commentLog += `${issue.user.login} created the issue:\n "${issue.body}"\n`
  //for (const comment of comments) {
  //  if(
  //    (comment.user.login != "github-actions[bot]") && 
  //    (!comment.body.startsWith("/"))
  //  ){
  //    commentLog += `${comment.user.login} says:\n"${comment.body}"\n`
  //  }
  //}

  const client = new BedrockRuntimeClient({ region: process.env.AWS_REGION });

  // There can be a lot more prompt engineering done for the perfect summarizations, this one works really well however.
  const prompt = `Give me a short summary of this GitHub Issue reply chain. Include details on what the issue is, and what was the conclusion. The full comment history is below: ${commentLog}`;

  const content = [
    {
      type: "text",
      text: `Human: ${prompt}\nAssistant:`
    }
  ];

  const messages = [
    {
      role: "user",
      content,
    }
  ];

  const modelInput = {
    anthropic_version: "bedrock-2023-05-31",
    max_tokens: 16384, // Adjust this if issue comment chain is long.
    messages: messages
  };

  const command = new InvokeModelCommand({
    contentType: "application/json",
    body: JSON.stringify(modelInput),
    modelId: process.env.MODEL_ID,
  });

  console.log("Prompting LLM with:\n" + JSON.stringify(modelInput));

  try {
    const response = await client.send(command);
  } catch (error) {
    console.log("Failure: Unable to access Bedrock. Either invalid credentials or a service outage!");
    throw error;
  }

  const responseBody = JSON.parse(new TextDecoder().decode(response.body));
  const generation = responseBody.content[0].text;

  console.log(`Raw response:\n${JSON.stringify(response)}`);
  console.log(`parsed response:\n${generation}`);

  await octokit.rest.issues.createComment({
    owner: context.repo.owner,
    repo: context.repo.repo,
    issue_number: context.issue.number,
    body: generation,
  });

  console.log("Finished!");
  return;
})();