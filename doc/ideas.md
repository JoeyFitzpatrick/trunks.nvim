# Ideas for features and improvements
This holds some random ideas I have until we get to actually using an issue tracker.

## Features

## Improvements

### Git pull can't rebase multiple branches
Sometimes when using the `git pull` mapping in a UI, instead of pulling, there is an error that says `can't rebase onto multiple branches`. This usually goes away after pulling a second or third time. It would be nice if this just didn't happen at all. I think this has something to do with `git fetch` or some other background command running, because sometimes this occurs even when I just open Trunks and use pull without switching branches.

### Git log --graph
Make `:G log --graph` highlight the graph characters and actually fetch the commits for keymaps. There's a plugin that exists that we could make an integration for, or we could just do a really simple version ourselves.

### Git diff keymaps
When using a command like `:G show abc123`, there are keymaps that allow for opening files and diffs for a the given commit. It would be nice to have the same keymaps for `:G diff abc123`. For `show`, there are maps to open a file at the given commit, or at the commit _before_ the given commit. For `diff`, we'd probably want to use that, but also support a commit range or multiple given commits, so in the case of `:G diff commit1 commit2`, the "previous" file would be `commit1`.
