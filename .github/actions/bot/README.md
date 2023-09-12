# bot

This GitHub Action parses commands from pull request comments and executes them.

Only authorized users (members and owners of this repository) are able to execute commands.

Commands look like:
```
/echo hello world
```

Multiple commands can be included in a comment, one per line; but each command must be unique.
