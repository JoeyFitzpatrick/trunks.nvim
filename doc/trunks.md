# Installation
- [lazy.nvim](https://github.com/folke/lazy.nvim)
```lua
{
    "JoeyFitzpatrick/trunks.nvim",
    -- TODO: (you) - Make sure your first release matches v1.0.0 so it auto-releases!
    version = "v1.*",
}
```

Note: lazy loading is handled internally, so it is not required to lazy load Trunks. With that being said, if you want to lazy load Trunks, you should be able to lazy load it however you normally lazy load plugins.


# Configuration
(These are default values)

- [lazy.nvim](https://github.com/folke/lazy.nvim)
```lua
{
    "JoeyFitzpatrick/trunks.nvim",
    config = function()
        vim.g.trunks_configuration = {
            -- Default configuration
            -- By default, Trunks attempts to prevent nested nvim sessions, in cases
            -- where a terminal opened by Trunks opens an editor (like the commit editor).
            -- Set this to false to allow "nvim inception" to occur (or handle yourself).
            prevent_nvim_inception = true,
            home = {
                keymaps = {
                    -- NOTE: setting a keymap to nil disables it, e.g. `next = nil`
                    next = "l", -- Move right through home options
                    previous = "h", -- Move left through home options
                },
            },
            auto_display = {
                keymaps = {
                    scroll_diff_down = "J",
                    scroll_diff_up = "K",
                    toggle_auto_display = "<tab>",
                },
            },
            blame = {
                keymaps = {
                    checkout = "c",
                    commit_details = "<enter>",
                    diff_file = "d",
                    reblame = "r", -- Display the file as of the given commit, then blame from that commit
                    return_to_original_file = "gq", -- If in reblamed file, return to original
                    show = "s", -- Output of `git show` for the given commit
                },
            },
            branch = {
                keymaps = {
                    delete = "d", -- Display a popup with branch deletion options
                    log = "<enter>", -- Display commits for branch under cursor
                    new_branch = "n", -- New branch from branch under cusor
                    pull = "p",
                    push = "<leader>p",
                    rename = "rn", -- Rename branch under cursor
                    spinoff = "S", -- Create new branch off of current, then reset current to upstream
                    switch = "s", -- Switch to branch under cursor
                },
            },
            commit_details = {
                auto_display_on = true,
                keymaps = {
                    edit_file = "e",
                    restore_popup = "R",
                    show_all_changes = "<enter>",
                },
            },
            commit_popup = {
                keymaps = { -- Run git commit with various options
                    commit = "o", -- Just a regular commit (no options)
                    commit_amend = "a",
                    commit_amend_reuse_message = "A",
                    commit_dry_run = "d",
                    commit_no_verify = "n",
                    commit_instant_fixup = "F", -- Run :Trunks commit-instant-fixup
                },
            },
            diff = {
                keymaps = {
                    next_hunk = "J",
                    previous_hunk = "K",
                    stage = "s", -- Stage hunk in normal mode, stage selected lines in visual mode
                },
            },
            difftool = {
                auto_display_on = true,
            },
            git_filetype = {
                keymaps = {
                    show_details = "<enter>", -- Show details for item under cursor
                },
            },
            log = {
                keymaps = {
                    checkout = "c", -- Checkout commmit under cursor
                    commit_details = "<enter>",
                    diff_commit_against_head = "d",
                    commit_drop = "D",
                    pull = "p",
                    push = "<leader>p",
                    rebase = "rb", -- Interactive rebase from current commit to commit under cursor
                    reset = "rs", -- Reset to commit under cursor
                    revert = "rv", -- Revert commit under cursor, but don't commit changes
                    revert_and_commit = "rV", -- Revert commit under cursor, and commit the revert
                    show = "s",
                },
            },
            open_files = {
                keymaps = { -- When available, these open file under cursor in various UIs
                    open_in_current_window = "ow",
                    open_in_horizontal_split = "oh",
                    open_in_new_tab = "ot",
                    open_in_vertical_split = "ov",
                },
            },
            reflog = {
                keymaps = {
                    checkout = "c",
                    commit_details = "<enter>",
                    recover = "r",
                    show = "s",
                },
            },
            restore_popup = {
                keymaps = {
                    restore_from_commit = "c", -- Restore file from the given commit
                    restore_from_commit_before = "b", -- Restore file from commit before given commit
                },
            },
            stash = {
                auto_display_on = true,
                keymaps = {
                    apply = "a",
                    drop = "d",
                    pop = "p",
                    show = "<enter>",
                },
            },
            stash_popup = {
                keymaps = {
                    stash_all = "a",
                    stash_staged = "s",
                },
            },
            status = {
                auto_display_on = true,
                keymaps = {
                    commit_popup = "c",
                    diff_file = "D",
                    edit_file = "<enter>", -- Close status UI and navigate to file under cursor
                    pull = "p",
                    push = "<leader>p",
                    restore = "d", -- Display a popup with options for `git restore`
                    stage = "s", -- (un)stage file under cursor
                    stage_all = "a",
                    stash_popup = "S",
                },
            },
            time_machine = {
                auto_display_on = true,
                keymaps = {
                    commit_details = "<enter>",
                    diff_against_previous_commit = "d", -- Diff file against previous commit
                    diff_against_head = "D", -- Diff file against HEAD
                },
            },
            time_machine_file = {
                keymaps = {
                    next = "<C-n>", -- Navigate to next revision for file
                    previous = "<C-p>", -- Navigate to previous revision for file
                },
            },
            -- End of default configuration
        }
    end
}
```

# Usage
1. To use this plugin, simply call git commands from command mode, using the `:G` command. Many commands will simply call the git command in terminal mode, with some improvements:
* The terminal can be remove by pressing "enter", to make it convenient to remove the terminal once you're done with the output

There are some advantages to using terminal mode for these commands, as opposed to a regular buffer or printing command output:
* Command output will sometimes be mangled when translated to a buffer or printed, this is avoided with a terminal
* Command output keeps it's coloring
* Existing tools such as `delta` or `diff-so-fancy` that improve git output can still be leveraged

Note that using the `%` character will expand it to the current buffer's filename, similar to vim-fugitive, e.g. `:G log --follow %` to see commits that changed the current file. The `%` character will not expand if it is between quotes, so a command like `:G commit -m 'improved performance by 2%'` won't expand the `%` character, it will just be `%`.

# Keymaps for Raw Git Output
When a command outputs raw git output (for example, `:G log -p`), a keymap is created to show details for the item under the cursor. By default, this is `<enter>`. Some details:
* If the current line is a filepath, e.g. `--- a/lua/trunks/_ui/keymaps/git_filetype_keymaps.lua`, it opens the file at that revision. Lines that start with `---` are the revision before the commit associated with this change, lines that begin with `+++` are the revision at that commit.
* If the line begins with `diff` or `@@`, the previous and next versions of the file, relative to that commit, are opened in a vim diff.
* Otherwise, the commit is opened in the commit details UI.

It's worth noting that similar functionality already exists in vim-fugitive, with some minor differences.

Additionally, keymaps are added to open a file under the cursor in a split, tab, or the current window. These are mnemonic by default:
* `ow` to [o]pen in current [w]indow
* `oh` to [o]pen in [h]orizontal split
* `ov` to [o]pen in [v]ertical split
* `ot` to [o]pen in a [t]ab

There are other UIs for which these "open file" keymaps are added as well.

# Special Commands
Some git commands benefit from a tighter integration with the editor. These are handled differently than just running the command in terminal mode. This typically means opening a buffer that serves as a UI for the command, but not always (for instance, `mergetool` and `grep` open the quickfix list). Here are the special commands:
* `:G blame`
* `:G branch`
* `:G commit`
* `:G difftool`
* `:G grep`
* `:G log`
* `:G mergetool`
* `:G reflog`
* `:G show`
* `:G stash list`
* `:G {command} -h`
* `:G {command} --help`

Note that for any command that brings up a UI:
* You can close the UI by pressing `q`, in addition to the normal methods, such as `:q`
* The jumplist still works like normal `<C-i>` and `<C-o>`
* You can view keymaps by pressing `g?`

Using the `:G` command renders a home ui, that will display some status info. This includes the git status of all changed files,
a diff split to display these changes, and some keymaps to manipulate these files.
Use `h` and `l` to then display the UI for  `git branch`, `git log`, and `git stash`, all of which are further detailed below.

## Blame
Like vim-fugitive, running `:G blame` will open a blame window to the left, that uses `:h scrollbind` to sync with with the opened file.
From there, many of the keymaps for the commit UI also work in the blame UI.
The [default configuration section](#configuration) shows every keymap, as does pressing `g?` in the blame UI.

## Branch
`:G` commands that display a list of branches, such as `:G branch`, `:G branch --all`, `:G branch --merged`,
and so on, bring up a branch UI, from which keymaps can be used to view commits, rename branches, merge branches, etc.
The [default configuration section](#configuration) shows every keymap, as does pressing `g?` in the branch UI.

G branch commands that do not display a list of branches, such as `:G branch --delete`, run the command in terminal mode, as if it were a non-special command.

## Commit
`:G commit` will open an editor to create the commit message when that message is not passed to the command, 
e.g. `git commit` (no message, opens the editor) vs `git commit -m "some message"` (does not open the commit message editor).
When the commit message editor is opened, Trunks opens it in the current Neovim instance.
You can write and quit the editor (`:wq`) to apply the message, or simply close the editor without saving to abort the commit due to an empty commit message.
If the commit message editor doesn't need to open, the command will just run in terminal mode like most other commands.

## Difftool
Trunks's `difftool` command, e.g. `:G difftool abc123` or `:G difftool abc123..def456`, will open a UI that allows for seeing the diff introduced by a commit, or the diff between two commits. Note that if a commit range is given, e.g. `abc123..def456`, using the open-file keymaps will use the latter commit. So in this example, using `oh` to open a file in a horizontal split would use commit `def456`.

When used without arguments, `difftool` uses `HEAD` as the commit to diff against, e.g. `:G difftool` is the same as `:G difftool HEAD`. This is useful for diffing the working tree against HEAD.

## Grep
Trunks's `:G grep` command is pretty simple. It just opens a quickfix list with the results of the grep command. Note that while `git grep` supports grepping across past revisions, `:G grep` currently only supports grepping the working tree.

Other than that, you should mostly be able to use `:G grep` exactly as you'd expect.

## Log
`:G log` commands will typically open a UI. The [default configuration section](#configuration) shows every keymap, as does pressing `g?` in the log UI.

When using the `:G log` command without arguments, a default [`--pretty`](https://git-scm.com/docs/pretty-formats) format option 
is passed to the `log` command to change how the output looks.
Passing a `--pretty` option, such as `:G log --pretty=full`, overrides the default format.

### Log -L
`:G log` has a `-L` flag, as shown [in the docs](https://git-scm.com/docs/git-log#Documentation/git-log.txt--Lltstartgtltendgtltfilegt). This can be used to see the commits that changed just the line numbers given, e.g. `git log -L20,40:example.lua`, to see just the commits that changed lines from 20 to 40 in `example.lua`.

In many cases, this can be an extremely useful way to search for changes, as opposed to running something like `git log --follow example.lua`, which could show commits that made changes that you don't care about. With Trunks, if you make a visual selection and run `:'<,'>G log -L`, without passing line numbers or a file name, it will pass the line numbers and file name automatically to the git command, making it much more convenient to use.

### Log -S
`:G log` has a `-S` flag, as shown [in the docs](https://git-scm.com/docs/git-log#Documentation/git-log.txt-code-Sltstringgtcode).
This can be used to see the commits that changed the number of times a given search term appeared in the codebase. For instance, running `:G log -S myFunc` will show all commits where `myFunc` was either added or removed.

This can very useful. With Trunks, running this command in visual mode will use your visually selected text as the search term., e.g. `:G log -S` while text is visually selected.

## Mergetool
`:G mergetool` opens a quickfix list with the locations of all merge conflicts. Trunks doesn't have an integrated merge conflict resolution solution currently, but it has these mappings:
<Plug>(Trunks-resolve-base): when the cursor is on a merge conflict, keep the "base" code
<Plug>(Trunks-resolve-ours): when the cursor is on a merge conflict, keep the "ours" code
<Plug>(Trunks-resolve-theirs): when the cursor is on a merge conflict, keep the "theirs" code
<Plug>(Trunks-resolve-all): when the cursor is on a merge conflict, keep all code

To use such a mapping, you can do something like this:

```lua
vim.keymap.set("n", "<leader>rb", "<Plug>(Trunks-resolve-base)")
```

## Show
Running `:G show` commands will just open their output in the current window. You can close this with `q` like other Trunks buffers.

## Stash List
Running `:G stash list` will open a UI, in which you can view, pop, apply, and drop stashes. 
Other stash commands, like `:G stash show`, run in terminal mode like most other commands.

## Help Commands
Running a git help command, such as `:G commit -h` or `:G log --help`, will open that help file in the current window. 
This way, you can use your normal vim navigation to move through the docs, versus opening a pager. 
You can close it by pressing `q` to return to your last buffer.

# Miscellaneous Command Changes
Some git commands are changed for convenience.

## Git Switch
When running `:G switch origin/some-branch`, with no command options like `--create`, `origin/` is removed from the command, in order to make auto-completion work and still allow switch to the branch. In other words, if the actual command that runs is `git switch origin/some-branch`, you'll get an error, but running `git switch some-branch` will create a local branch off of that remote branch, which is normally what you'd want.

If you pass any options to the command, like `:G switch origin/some-branch --create`, this behavior is not used.

## Quiet commands
You can pass `--quiet` to some commands to run the commands without opening a UI of any kind, e.g. `:G switch main --quiet`. Currently this only works for "write" commands, and not "read" commands, as I can't think of a reason why one would want to run a "read" command with `--quiet`. For instance, `:G log --quiet` doesn't make a lot of sense because the point of log is to show information.

# Custom Commands
Trunks provides some commands that are not valid git commands. Instead of the `:G` command, these custom commands are under the `:Trunks` command, and `:G` is reserved for valid git commands.

### browse
`:Trunks browse` opens a tab in your web browser at the remote URL of the current file. When used in visual mode, it opens the tab with the line numbers added, assuming the host in question supports this.

### commit-drop
`:Trunks commit-drop {commit}` can be used to drop an arbitrary commit. Under the hood, it's an interactive rebase that drops the commit, so this is a destructive command that should be used with caution.

### commit-instant-fixup
`:Trunks commit-instant-fixup {commit}` will apply your staged changes to the given commit. This is useful for applying changes to a past commit in order to maintain a logic commit history (think atomic commits). This is a rebase under the hood, so use with caution.

If no commit is given, a list of commits (e.g. `git log` output) is shown, so that a commit can be chosen to fixup.

### time-machine
`:Trunks time-machine <optional filename>` creates a time-machine buffer for the given file, or the current buffer if a file is not given. This displays a list of commits that changed the file. Putting the cursor on a given commit will display the diff for that file at that commit. There is a keymap to open the file at the given commit, plus other keymaps that can be viewed with `g?`.

Once you have opened a file at a revision, there are keymaps to move to the next/previous revision, as well as open diff splits.

### time-machine-next
In a time-machine buffer, move to the next most recent revision for the given file. If a diff split is open, re-generate that diff.

### time-machine-previous
In a time-machine buffer, move to the previous revision for the given file. If a diff split is open, re-generate that diff. If this is run on a regular buffer, open a time-machine buffer at the previous revision for the current buffer.

### vdiff
`:Trunks vdiff` opens a vertical split and uses `vimdiff` to diff the current file against `HEAD`. You can pass a commit, e.g. `:Trunks vdiff abc123`, to diff the current file against the same file in the given commit. You can also pass a branch, e.g. `:Trunks vdiff some-branch`. See `:h vimdiff`.

### hdiff
Like `:Trunks vdiff`, except horizontal instead of vertical. `:Trunks hdiff` opens a horizontal split and uses `vimdiff` to diff the current file against `HEAD`. You can pass a commit, e.g. `:Trunks hdiff abc123`, to diff the current file against the same file in the given commit. You can also pass a branch, e.g. `:Trunks hdiff some-branch`. See `:h vimdiff`.

### diff-qf
`:Trunks diff-qf` opens a tab that uses the quickfix list and native Vim diffing, to support viewing and navigating through diffs. When called without arguments, the working tree is diffed against HEAD. You can diff the working tree against any commit or branch by passing it as an argument, e.g. `:Trunks diff-qf abc123` or `:Trunks diff-qf my-other-branch`. 

When `:Trunks diff-qf` is used, a few things happen:

- A new tab opens
- The quickfix list is populated with all of the locations where the working tree differs from the given commit (or HEAD)
- Within this tab, moving to one of the locations from the quickfix list will open a split. The left side is the working tree, the right side is the same file at the given commit. The file and its split are diffed against eachother using `diffthis`.

You can move between locations by selecting them from the quickfix list, or using `cnext` and `cprevious`, and the tab can be closed with `tabclose`.

# UI Management (Tabs, Windows, Buffers)
When Trunks opens a UI, this will typically either open a new buffer in the current window, or open a new window in a split. 
In either case, the window can be closed with the `q` keymap, which will return you to the last buffer that was open.

If you want to open something in a non-standard ui, this is supported natively via command mode:
Open `G status` in a left split instead of a full window: `split | G status`
Open `G branch` in a right split instead of a full window `rightbelow vsplit | G branch`
Note that this functionality can be used in both command mode and in keymaps.

### Auto-display
Some UIs, such as the status UI, will automatically display another window in a split when moving the cursor in the main window.
* The status UI displays a diff for the file under the cursor
* The commit details UI displays a diff for the file under the cursor for the given commit
* The stash UI displays a diff for the entire stash under the cursor

To toggle the auto-display, enter the toggle keymap, which by default is `<tab>`.

## User Autocmds
There is a `TrunksUiOpened` event that fires when a Trunks UI opens. You can use this autocmd to run custom logic whenever a Trunks UI opens. For instance, to set a custom keymap when the log UI opens:
```lua
vim.api.nvim_create_autocmd("TrunksUiOpened", {
    desc = "Your custom autocmd",
    callback = function(data)
        local ui_type = data.ui_type -- "buffer" or "quickfix"
        local ui_name = data.ui_name -- name of UI, "log" in this case
        if ui_name == "log" then
            vim.keymap.set("n", "p", function ()
                vim.print(ui_type, ui_name)
            end,
            {buffer = 0}
            )
        end
    end,
})
```

# Optional Dependencies
It is recommended, though not required, to use a tool that improves the output of git commands. Some recommendations:
* [delta](https://github.com/dandavison/delta): used in the demos/examples
* [diff-so-fancy](https://github.com/so-fancy/diff-so-fancy)

# Development and Contributing
I welcome users of any experience level to contribute to Trunks and improve the project. If you'd like to contribute by writing code, please run `scripts/dev_setup/dev_setup.sh` first, which will set up a pre-commit hook that runs tests and some checks. The same checks run in CI, but this will help you catch issues before pushing up code. Note that you may need to run `chmod +x scripts/dev_setup/dev_setup.sh` first, to set up correct permissions to run the script.

Improvements to the documentation are also welcome. Additionally, there are templates for asking questions, bug reports, and feature requests, all which are also good ways to contribute.

# Tests
## Initialization
Run this line once before calling any `busted` command

```sh
eval $(luarocks path --lua-version 5.1 --bin)
```


## Running
Run all tests
```sh
luarocks test --test-type busted
# Or manually
busted .
# Or with Make
make test
```

It's worth noting that running with `make tests` will download some test dependencies that add LSP types
for `busted` and `luassert`. These are gitignored.

Run tests based on tags
```sh
busted . --tags=simple
```

We might not have any tagged tests, but to make one, set up
as test like this:
```lua
describe("User management controls #simple", function ()...
```

# Tracking Updates
See [doc/news.txt](doc/news.txt) for updates.

# Credits
Thank you to Samuel Williams and the maintainers of [nvim-unception](https://github.com/samjwill/nvim-unception).
Some code from that plugin was vendored into Trunks to support preventing nested nvim sessions when opening an editor
from within an nvim terminal, e.g. the commit editor when running `:G commit`.

Thanks to Tim Pope and the maintainers of [vim-fugitive](https://github.com/tpope/vim-fugitive), an absolutely incredible vim 
plugin that _heavily_ influenced Trunks.

Thanks to Jesse Duffield and the maintainers of [lazygit](https://github.com/jesseduffield/lazygit), a sick terminal
git TUI that also heavily influenced Trunks.

Thanks to Jonas Bernoulli, Kyle Meyer, and the maintainers of [magit](https://github.com/magit/magit). I've never
personally used it, but its wonderful documentation inspired both some features and design priniciples of Trunks.
