# Ideas for features and improvements
This holds some random ideas I have until we get to actually using an issue tracker.

## Features

### Git restore hunk/lines/file from previous commit
In a file from a previous commit, be able to:
* visually select lines to restore
* restore the entire file

In a git patch, be able to do the above, as well as:
* restore a single hunk

### Command log
A user-facing command log would have a couple of benefits:
- It tells the user what commands are running. This allows them to find bugs more easily, recover from catastrophe better, and in general have better insight into what the plugin is doing.
- It is the first step towards git undo commands, if we ever want to implement that.

There's an open question of how to surface this to users. Could be a trunks command. That could allow for args to be passed that allow for showing "main" commands or "every command that runs".

## Improvements

### Git pull can't rebase multiple branches
Sometimes when using the `git pull` mapping in a UI, instead of pulling, there is an error that says `can't rebase onto multiple branches`. This usually goes away after pulling a second or third time. It would be nice if this just didn't happen at all. I think this has something to do with `git fetch` or some other background command running, because sometimes this occurs even when I just open Trunks and use pull without switching branches.

### Git log -S with multiline visual selection
It would be awesome if using `:G log -S` from visual mode worked with a multiline selection. One way this _could_ work is to use concepts from [this blog post](https://hoelz.ro/blog/applying-gits-pickaxe-option-across-multiple-lines-of-yaml-using-textconv). The gist of it is:
* create a script that replaces new lines in a diff with a string like `\n`
* pass this to the `log` command using the `-c` flag
* pass the `--pickaxe-regex` option to the command to ignore any whitespace changes between lines

This is hilariously over-the-top, but it would be pretty cool.

### Git log --graph
Make `:G log --graph` highlight the graph characters and actually fetch the commits for keymaps. There's a plugin that exists that we could make an integration for, or we could just do a really simple version ourselves.

### Git diff keymaps
When using a command like `:G show abc123`, there are keymaps that allow for opening files and diffs for a the given commit. It would be nice to have the same keymaps for `:G diff abc123`. For `show`, there are maps to open a file at the given commit, or at the commit _before_ the given commit. For `diff`, we'd probably want to use that, but also support a commit range or multiple given commits, so in the case of `:G diff commit1 commit2`, the "previous" file would be `commit1`.
