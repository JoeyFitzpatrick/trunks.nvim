# trunks.nvim

Trunks is a Neovim git client. It has some similarities to [vim-fugitive](https://github.com/tpope/vim-fugitive). This plugin ships with two commands:
- The `:G` command, which invokes an arbitrary git command, e.g. `:G commit`, `:G log --oneline`, etc. You can also run `:G` to open the home UI, which displays a git status buffer and allows for navigation via `h` and `l` to see branch, log, and stash buffers. The `%` character will expand to the current buffer's filename, similar to vim-fugitive, e.g. `:G log -- %` to see commits that changed the current file.
- The `:Trunks` command, which provides subcommands for git features that aren't already git commands. For example, `:Trunks vdiff` opens a vim diff in a vertical split, `:Trunks time-machine` opens a UI to navigate between revisions of a file, etc.

The main benefits of using Trunks:
- Most `:G` commands will display their output in terminal mode. This is a powerful concept:
  - Long running commands will start displaying output immediately, instead of freezing the editor.
  - Terminal extensions for git, like [delta](https://github.com/dandavison/delta) or [diff-so-fancy](https://github.com/so-fancy/diff-so-fancy), will work just like they do in the terminal.
  - You can navigate around the output of a git command with your familiar vim motions, because it's just a buffer. Want to use `/` to search for errors in your pre-commit hook, or look through a diff while composing your git commit message? It's just like any other buffer.
- Autocompletion for git commands, e.g. typing `:G switch` will cause valid branches to be autocompleted.
- Keymaps for git actions in various git contexts. For example, from the status buffer (via `:G`), you're one or two keys away from pull, push, diff, commit, stash, restore, and staging.
- UIs always show the up-to-date git state. If you're in a log buffer and run `:G pull`, the buffer will rerender and you'll see the pulled commits.
- Discoverability: some keymaps will open a popup with various keymap options to use (a la [magit](https://magit.vc/)), and you can always press `g?` to get a floating window with all available keymaps.

As mentioned above, there is also the `:Trunks` command, which provides some additional git functionality:
- `:Trunks vdiff` and `:Trunks hdiff`, which diff the current buffer using a vim diff, in a vertical or horizontal split
- `:Trunks browse`, to open the current buffer in your hosting provider (currently, GitHub, GitLab, and Bitbucket are supported). Use in visual mode to link to specific lines.
- `:Trunks commit-drop`: pass a commit hash to it, and that commit is dropped. Use without arguments to open a log buffer to choose a commit.
- `:Trunks commit-instant-fixup`: similar to `:Trunks commit-drop`, except instead of dropping a commit, apply staged changes to it.
- `:Trunks time-machine`: in a new tab, display a log buffer with commits that changed the current buffer. Press `<Tab>` to toggle the auto-diff. Use `:Trunks time-machine-next` and `:Trunks time-machine-previous` to cycle the current buffer through revisions, vaguely akin to the emacs [git-timemachine](https://codeberg.org/pidu/git-timemachine) plugin.

Here's an example of running some git commands with Trunks:
![trunks_some_commands](https://github.com/user-attachments/assets/a93743fa-056e-4d4d-917d-95e0dc0f2a86)

🚧 NOTE: this plugin is in an alpha state. API changes and bugs are expected. 🚧


# Installation
- [lazy.nvim](https://github.com/folke/lazy.nvim)
```lua
{
    "JoeyFitzpatrick/trunks.nvim",
}
```

Note: lazy loading is handled internally, so it is not required to lazy load Trunks. With that being said, if you really want to lazy load Trunks, you should be able to lazy load it however you normally lazy load plugins.

# Configuration
(These are default values)

- [lazy.nvim](https://github.com/folke/lazy.nvim)
```lua
{
    "JoeyFitzpatrick/trunks.nvim",
    config = function()
        -- The next two lines allow the lua LSP to autocomplete config options
        ---@module "trunks"
        ---@type trunks.Configuration
        vim.g.trunks_configuration = {
            -- Default configuration
            -- By default, Trunks attempts to prevent nested nvim sessions, in cases
            -- where a terminal opened by Trunks opens an editor (like the commit editor).
            -- Set this to false to allow "nvim inception" to occur (or handle yourself).
            prevent_nvim_inception = true,
            pager = "", -- delta, diff-so-fancy, difft, etc.
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
                auto_display_on = false,
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
            -- End of default configuration
        }
    end
}
```


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
Thank you to Samuel Williams and the maintainers of [nvim-unception](https://github.com/samjwill/nvim-unception). Some code from that plugin was vendored into Trunks to support preventing nested nvim sessions when opening an editor from within an nvim terminal, e.g. the commit editor when running `:G commit`.

Thanks to Tim Pope and the maintainers of [vim-fugitive](https://github.com/tpope/vim-fugitive), an absolutely incredible vim plugin that _heavily_ influenced Trunks.
