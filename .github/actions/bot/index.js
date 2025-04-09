// this script cannot require/import, because it's called by actions/github-script.
// any dependencies must be passed in the inline script in action.yaml

async function bot(core, github, context, uuid) {
    const payload = context.payload;

    if (!payload.comment) {
        console.log("No comment found in payload");
        return;
    }
    console.log("Comment found in payload");

    // user's org membership must be public for the author_association to be MEMBER
    // go to the org's member page, find yourself, and set the visibility to public
    const author = payload.comment.user.login;
    const authorized = ["OWNER", "MEMBER"].includes(payload.comment.author_association);
    if (!authorized) {
        console.log(`Comment author is not authorized: ${author}`);
        return;
    }
    console.log(`Comment author is authorized: ${author}`);

    let commands;
    try {
        commands = parseCommands(uuid, payload, payload.comment.body);
    } catch (error) {
        console.log(error);
        const reply = `@${author} I didn't understand [that](${payload.comment.html_url})! 🤔\n\nTake a look at my [logs](${getBotWorkflowURL(payload, context)}).`
        replyToCommand(github, payload, reply);
        return;
    }
    if (commands.length === 0) {
        console.log("No commands found in comment body");
        return;
    }
    const uniqueCommands = [...new Set(commands.map(command => typeof command))];
    if (uniqueCommands.length != commands.length) {
        replyToCommand(github, payload, `@${author} you can't use the same command more than once! 🙅`);
        return;
    }
    console.log(commands.length + " command(s) found in comment body");

    for (const command of commands) {
        const reply = await command.run(author, github);
        if (typeof reply === 'string') {
            replyToCommand(github, payload, reply);
        } else if (reply) {
            console.log(`Command returned: ${reply}`);
        } else {
            console.log("Command did not return a reply");
        }
    }
}

// replyToCommand creates a comment on the same PR that triggered this workflow
function replyToCommand(github, payload, reply) {
    github.rest.issues.createComment({
        owner: payload.repository.owner.login,
        repo: payload.repository.name,
        issue_number: payload.issue.number,
        body: reply
    });
}

// getBotWorkflowURL returns an HTML URL for this workflow execution of the bot
function getBotWorkflowURL(payload, context) {
    return `https://github.com/${payload.repository.owner.login}/${payload.repository.name}/actions/runs/${context.runId}`;
}

// parseCommands splits the comment body into lines and parses each line as a command or named arguments to the previous command.
function parseCommands(uuid, payload, commentBody) {
    const commands = [];
    if (!commentBody) {
        return commands;
    }
    const lines = commentBody.split(/\r?\n/);
    for (const line of lines) {
        console.log(`Parsing line: ${line}`);
        const command = parseCommand(uuid, payload, line);
        if (command) {
            commands.push(command);
        } else {
            const namedArguments = parseNamedArguments(line);
            if (namedArguments) {
                const previousCommand = commands.at(-1);
                if (previousCommand) {
                    if (typeof previousCommand.addNamedArguments === 'function') {
                        previousCommand.addNamedArguments(namedArguments.name, namedArguments.args);
                    } else {
                        throw new Error(`Parsed named arguments but previous command (${previousCommand.constructor.name}) does not support arguments: ${JSON.stringify(namedArguments)}`);
                    }
                } else {
                    // don't treat this as an error, because the named argument syntax might just be someone '+1'-ing.
                    console.log(`Parsed named arguments with no previous command: ${JSON.stringify(namedArguments)}`);
                }
            }
        }
    }
    return commands
}

// parseCommand parses a line as a command.
// The format of a command is `/NAME ARGS...`.
// Leading and trailing spaces are ignored.
function parseCommand(uuid, payload, line) {
    const command = line.trim().match(/^\/([a-z\-]+)(?:\s+(.+))?$/);
    if (command) {
        return buildCommand(uuid, payload, command[1], command[2]);
    }
    return null;
}

// buildCommand builds a command from a name and arguments.
function buildCommand(uuid, payload, name, args) {
    switch (name) {
        case "echo":
            return new EchoCommand(uuid, payload, args);
        case "clear":
            return new ClearCommand(uuid, payload, args);
        case "ci":
            return new CICommand(uuid, payload, args);
        default:
            console.log(`Unknown command: ${name}`);
            return null;
    }
}

// parseNamedArgument parses a line as named arguments.
// The format of a command is `+NAME ARGS...`.
// Leading and trailing spaces are ignored.
function parseNamedArguments(line) {
    const parsed = line.trim().match(/^\+([a-z\-]+(?::[a-z\-\d_]+)?)(?:\s+(.+))?$/);
    if (parsed) {
        return {
            name: parsed[1],
            args: parsed[2]
        }
    }
    return null;
}

class EchoCommand {
    constructor(uuid, payload, args) {
        this.phrase = args ? args : "echo";
    }

    run(author) {
        return `@${author} *${this.phrase}*`;
    }
}

class ClearCommand {
    constructor(uuid, payload, args) {
        this.repository_owner = payload.repository.owner.login;
        this.repository_name = payload.repository.name;
        this.pr_number = payload.issue.number;
    }

    async run(author, github) {
        const comments = await github.rest.issues.listComments({
            owner: this.repository_owner,
            repo: this.repository_name,
            issue_number: this.pr_number,
            per_page: 100 // max allowed
            // TODO: implement pagination?
            // we're unlikely to have >100 comments, so not necessary for now
        });
        for (const comment of comments.data) {
            if (comment.user.login == 'github-actions[bot]') {
                await github.rest.issues.deleteComment({
                    owner: this.repository_owner,
                    repo: this.repository_name,
                    comment_id: comment.id
                });
            }
        }
        return null;
    }
}

class CICommand {
    workflow_goal_prefix = "workflow:";
    constructor(uuid, payload, args) {
        this.repository_owner = payload.repository.owner.login;
        this.repository_name = payload.repository.name;
        this.pr_number = payload.issue.number;
        this.comment_url = payload.comment.html_url;
        this.comment_created_at = payload.comment.created_at;
        this.uuid = uuid;
        this.goal = "test";
        // "test" goal, which executes all CI stages, is the default when no goal is specified
        if (args != null && args !== "") {
            this.goal = args;
        }
        this.goal_args = {};
    }

    addNamedArguments(goal, args) {
        this.goal_args[goal] = args;
    }

    // a map of file path prefixes to OS distros that are associated with the file paths
    // a value of "*" implies multiple OS distros are associated with the path, and we should just rely on the workflow's default
    osDistroPathPrefixHints = {
        "templates/al2/": "al2",
        "templates/al2023/": "al2023",
        "templates/shared/": "*",
        "nodeadm/": "al2023",
    };

    async guessOsDistrosForChangedFiles(github) {
        const files = await github.rest.pulls.listFiles({
            owner: this.repository_owner,
            repo: this.repository_name,
            pull_number: this.pr_number
        });
        const osDistros = new Set();
        for (const file of files.data) {
            for (const [prefix, osDistro] of Object.entries(this.osDistroPathPrefixHints)) {
                if (file.filename.startsWith(prefix)) {
                    osDistros.add(osDistro);
                }
            }
        }
        if (osDistros.has('*')) {
            console.log("changed files matched a prefix mapped to the wildcard, not attempting to guess os_distros!");
            return null;
        }
        if (osDistros.size == 0) {
            return null;
        }
        return Array.from(osDistros).join(',');
    }

    async run(author, github) {
        const pr = await github.rest.pulls.get({
            owner: this.repository_owner,
            repo: this.repository_name,
            pull_number: this.pr_number
        });
        const mergeable = pr.data.mergeable;
        switch (mergeable) {
            case true:
                break;
            case false:
            case null:
                return `@${author} this PR is not currently mergeable, you'll need to rebase it first.`;
            default:
                throw new Error(`Unknown mergeable value: ${mergeable}`);
        }
        const merge_commit = await github.rest.repos.getCommit({
            owner: this.repository_owner,
            repo: this.repository_name,
            ref: pr.data.merge_commit_sha
        });
        if (new Date(this.comment_created_at) < new Date(merge_commit.data.commit.committer.date)) {
            return `@${author} this PR has been updated since your request, you'll need to review the changes.`;
        }
        const inputs = {
            uuid: this.uuid,
            pr_number: this.pr_number.toString(),
            git_sha: pr.data.merge_commit_sha,
            goal: this.goal,
            requester: author,
            comment_url: this.comment_url
        };
        for (const [goal, args] of Object.entries(this.goal_args)) {
            if (goal.startsWith(this.workflow_goal_prefix)) {
                inputs[goal.substring(this.workflow_goal_prefix.length)] = args;
            } else {
                inputs[`${goal}_arguments`] = args;
            }
        }
        if (!inputs.hasOwnProperty('os_distros')) {
            const osDistros = await this.guessOsDistrosForChangedFiles(github);
            if (osDistros != null) {
                inputs['os_distros'] = osDistros;
            }
        }
        console.log(`Dispatching workflow with inputs: ${JSON.stringify(inputs)}`);
        await github.rest.actions.createWorkflowDispatch({
            owner: this.repository_owner,
            repo: this.repository_name,
            workflow_id: 'ci-manual.yaml',
            ref: 'main',
            inputs: inputs
        });
        return null;
    }
}


module.exports = async (core, github, context, uuid) => {
    bot(core, github, context, uuid).catch((error) => {
        core.setFailed(error);
    });
}
