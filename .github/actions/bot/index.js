// this script cannot require/import, because it's called by actions/github-script.
// any dependencies must be passed in the inline script in action.yaml

async function bot(core, github, context, uuid) {
    const payload = context.payload;

    if (!payload.comment) {
        console.log("No comment found in payload");
        return;
    }
    console.log("Comment found in payload");

    const author = payload.comment.user.login;
    const authorized = ["OWNER", "MEMBER"].includes(payload.comment.author_association);
    if (!authorized) {
        console.log(`Comment author is not authorized: ${author}`);
        return;
    }
    console.log(`Comment author is authorized: ${author}`);

    const commands = parseCommands(uuid, payload, payload.comment.body);
    if (commands.length === 0) {
        console.log("No commands found in comment body");
        return;
    }
    const uniqueCommands = [...new Set(commands.map(command => typeof command))];
    if (uniqueCommands.length != commands.length) {
        console.log("Duplicate commands found in comment body");
        return;
    }
    console.log(commands.length + " command(s) found in comment body");

    for (const command of commands) {
        const reply = await command.run(author, github);
        if (typeof reply === 'string') {
            github.rest.issues.createComment({
                owner: payload.repository.owner.login,
                repo: payload.repository.name,
                issue_number: payload.issue.number,
                body: reply
            });
        } else if (reply) {
            console.log(`Command returned: ${reply}`);
        } else {
            console.log("Command did not return a reply");
        }
    }
}

// parseCommands splits the comment body into lines and parses each line as a command.
function parseCommands(uuid, payload, commentBody) {
    const commands = [];
    if (!commentBody) {
        return commands;
    }
    const lines = commentBody.split(/\r?\n/);
    for (const line of lines) {
        const command = parseCommand(uuid, payload, line);
        if (command) {
            commands.push(command);
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
        case "ci":
            return new CICommand(uuid, payload, args);
        default:
            console.log(`Unknown command: ${name}`);
            return null;
    }
}

class EchoCommand {
    constructor(uuid, payload, args) {
        this.phrase = args ? args : "echo";
    }

    run(author) {
        return `@${author} *${this.phrase}*`;
    }
}

class CICommand {
    constructor(uuid, payload, args) {
        this.repository_owner = payload.repository.owner.login;
        this.repository_name = payload.repository.name;
        this.pr_number = payload.issue.number;
        this.comment_url = payload.comment.html_url;
        this.uuid = uuid;
        this.goal = "test";
        // "test" goal, which executes all CI stages, is the default when no goal is specified
        if (args != null && args != "") {
            this.goal = args;
        }
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
        const inputs = {
            uuid: this.uuid,
            pr_number: this.pr_number.toString(),
            git_sha: pr.data.merge_commit_sha,
            goal: this.goal,
            requester: author,
            comment_url: this.comment_url
        };
        console.log(`Dispatching workflow with inputs: ${JSON.stringify(inputs)}`);
        await github.rest.actions.createWorkflowDispatch({
            owner: this.repository_owner,
            repo: this.repository_name,
            workflow_id: 'ci-manual.yaml',
            ref: 'master',
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