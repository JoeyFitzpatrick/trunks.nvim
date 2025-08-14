describe("diff-qf diff output parser", function()
    local parse_diff_output = require("trunks._ui.trunks_commands.diff_qf")._parse_diff_output

    it("returns a file locations for multiple hunks", function()
        local result = parse_diff_output({
            "diff --git c/README.md w/README.md",
            "index ce51519..24439ed 100644",
            "--- c/README.md",
            "+++ w/README.md",
            "@@ -102,6 +102,7 @@ Note: lazy loading is handled internally, so it is not required to lazy load Tru",
            '                     commit_amend_reuse_message = "A",',
            '                     commit_dry_run = "d",',
            '                     commit_no_verify = "n",',
            '+                    commit_instant_fixup = "F", -- Run :Trunks commit-instant-fixup',
            "                 },",
            "             },",
            "             diff = {",
            "diff --git c/doc/roadmap_to_beta.md w/doc/roadmap_to_beta.md",
            "index 868a119..9eef73e 100644",
            "--- c/doc/roadmap_to_beta.md",
            "+++ w/doc/roadmap_to_beta.md",
            "@@ -5,9 +5,6 @@ While the project is in alpha, we will not use versioning. Once all of the impro",
            " ",
            " ## Features",
            " ",
            "-### Display files in a tree",
            "-In all UIs that display files, we currently display all files in a flat structure; each file takes up one line. It would be great to be able to display files in a tree instead. This should be config driven. This should be doable for most, if not all, UIs. The first one to tackle would be the status UI.",
            "-",
            " ### Undo",
            " Not well thought out, but the idea is that we could undo some operations:",
            " * undo a merge commit (just reset to the commit before the merge probably)",
            "@@ -40,20 +37,31 @@ Users should be able to create their own keymaps for different UIs. This can be",
            " A potential pitfall here is that we currently map from command to key, not key to map. So we'd either need to invert existing keymaps, or support current mappings but allow new ones to be inverted.",
            " 2. Create autocmds for different UIs, so that keymaps could be created for a given UI as part of its autocmd. Not a huge fan of this approach, but there might be other reasons to create these autocmds anyways.",
            " ",
            "+### Quickfix list integration",
            "+Some ideas for quickfix list integrations that would be helpful:",
            "+",
            "+- Diffs could populate the quickfix list with all changes, so that one could navigate between the changes easily. Would be helpful for inspecting diffs and code review. This can work by calling `git diff`, parsing diff locations, filling out the quickfix list with these, and open the file and vdiff it each time it's opened. Could probably convert `:G difftool` to this, but we'd need a way to stage/unstage hunks/lines from these vidiff'ed files.",
            "+- Fugitive has a `:Gclog` command that would be nice to copy.",
            "+- A git grep integration would be nice.",
            "+- Mergetool already has quickfix list integration.",
            "+- Question: do we need a single command for all quickfix list stuff, like `:Trunks qf {subcommand}` or `:Trunks qf-{subcommand}`, or would ad-hoc commands be better, like `:G grep` just working? Leaning towards a single command to be explicit.",
            "+",
            " ## Improvements",
            " ",
            " ### Diff highlight engine",
            " I'm not a big fan of the built-in diff highlighting. It would be nice to have something closer to [delta](https://github.com/dandavison/delta). This would allow for using regular buffers for diffs in all cases, instead of terminal buffers, which would be a big win for functionality.",
            " ",
            "-I am pretty sure we can leverage virtual text to accomplish this. The gist of it would be:",
            "+There is prior art that leverages virtual text to accomplish this, but only for diffs for a single file. The gist of it would be:",
            " 1. Get diff output",
            " 1. Omit the first character of each line, except the @@ lines (aka context lines)",
            " 1. Highlight added/removed lines appropriately",
            " 1. Omit the context lines entirely, and replace with virtual text using `vim.api.nvim_buf_set_extmark`",
            " This should print the context lines, while not counting them for syntax highlighting purposes since they aren't actually in the buffer.",
            " ",
            "+Ideally, we'd be able to highlight diffs with multiple files with multiple file types. A rough idea is to use treesitter to highlight each part of the file as it's filetype, using nested treesitter query stuff. Not really sure how this works though.",
            "+",
            " ### Git pull can't rebase multiple branches",
            "-Sometimes when using the `git pull` mapping in a UI, instead of pulling, there is an error that says `can't rebase onto multiple branches`. This usually goes away after pulling a second or third time. It would be nice if this just didn't happen at all.",
            "+Sometimes when using the `git pull` mapping in a UI, instead of pulling, there is an error that says `can't rebase onto multiple branches`. This usually goes away after pulling a second or third time. It would be nice if this just didn't happen at all. I think this has something to do with `git fetch` or some other background command running, because sometimes this occurs even when I just open Trunks and use pull without switching branches.",
            " ",
            " ### Git log -S with multiline visual selection",
            " It would be awesome if using `:G log -S` from visual mode worked with a multiline selection. One way this _could_ work is to use concepts from [this blog post](https://hoelz.ro/blog/applying-gits-pickaxe-option-across-multiple-lines-of-yaml-using-textconv). The gist of it is:",
            "@@ -75,3 +83,6 @@ In git, many commands take a `--quiet` flag that surpresses informational messag",
            " ### Reblame handles files not in commit",
            " When reblaming a file that has a different name at a given commit, a pretty ugly error is shown. We should handle that more gracefully by either figuring out the old file name, or if that's not possible, show a better error.",
            " ",
            "+### Worktree UI improvements",
            "+There are some weird things that happen with worktrees and our strategy to respect the current buffer as the git dir. When changing to a different worktree and running a git command, the git command behaves as though we’re still in the previous dir. Additionally, changing back to the original worktree doesn’t seem to change back to the correct branch.",
            "+We definitely need a way to make worktrees not use the “respect buffer dir” logic, and we also need to see what’s going on with the branch changes not persisting.",
        })

        local expected = {
            { filename = "README.md", line_nums = { 105 } },
            { filename = "doc/roadmap_to_beta.md", line_nums = { 7, 40, 54, 61, 64, 86 } },
        }
        for i, _ in ipairs(expected) do
            assert.are.same(expected[i].filename, result[i].filename)
            assert.are.same(
                expected[i].line_nums,
                vim.tbl_map(function(line)
                    return line.line_num
                end, result[i].lines)
            )
        end
    end)

    it("returns a file locations for a complicated hunk", function()
        local result = parse_diff_output({
            "diff --git c/lua/trunks/_ui/popups/commit_popup.lua w/lua/trunks/_ui/popups/commit_popup.lua",
            "index 8b6683f..e82e9f7 100644",
            "--- c/lua/trunks/_ui/popups/commit_popup.lua",
            "+++ w/lua/trunks/_ui/popups/commit_popup.lua",
            "@@ -1,35 +1,61 @@",
            " local M = {}",
            " ",
            '+local popup = require("trunks._ui.popups.popup")',
            "+",
            " ---@param bufnr integer",
            "-local function set_keymaps(bufnr)",
            "+---@param ui_type string",
            "+---@return { basic: trunks.PopupMapping[], edit: trunks.PopupMapping[] }",
            "+local function get_keymaps_with_descriptions(bufnr, ui_type)",
            '     local keymaps = require("trunks._ui.keymaps.base").get_keymaps(bufnr, "commit_popup", { popup = true })',
            "-    local keymap_opts = { noremap = true, silent = true, buffer = bufnr, nowait = true }",
            '-    local set = require("trunks._ui.keymaps.set").safe_set_keymap',
            '+    local descriptions = require("trunks._constants.keymap_descriptions").long_descriptions[ui_type]',
            "+    local mappings = { basic = {}, edit = {} }",
            " ",
            "     local keymap_command_map = {",
            '-        [keymaps.commit] = "G commit",',
            '-        [keymaps.commit_amend] = "G commit --amend",',
            '-        [keymaps.commit_amend_reuse_message] = "G commit --amend --reuse-message HEAD --no-verify",',
            '-        [keymaps.commit_dry_run] = "G commit --dry-run",',
            '-        [keymaps.commit_no_verify] = "G commit --no-verify",',
            "+        basic = {",
            '+            [keymaps.commit] = "G commit",',
            '+            [keymaps.commit_amend] = "G commit --amend",',
            '+            [keymaps.commit_amend_reuse_message] = "G commit --amend --reuse-message HEAD --no-verify",',
            '+            [keymaps.commit_dry_run] = "G commit --dry-run",',
            '+            [keymaps.commit_no_verify] = "G commit --no-verify",',
            "+        },",
            "+        edit = {",
            '+            [keymaps.commit_instant_fixup] = "Trunks commit-instant-fixup",',
            "+        },",
            "     }",
            " ",
            "-    for keys, command in pairs(keymap_command_map) do",
            '-        set("n", keys, function()',
            "-            vim.api.nvim_buf_delete(bufnr, { force = true })",
            "-            vim.cmd(command)",
            "-        end, keymap_opts)",
            "+    for name, keys in pairs(keymaps) do",
            "+        if keys and keymap_command_map.basic[keys] then",
            "+            table.insert(mappings.basic, {",
            "+                keys = keys,",
            "+                description = descriptions[name],",
            "+                -- Yes, using keys as the key. Pretty disgusting and should be fixed.",
            "+                action = keymap_command_map.basic[keys],",
            "+            })",
            "+        end",
            "+        if keys and keymap_command_map.edit[keys] then",
            "+            table.insert(mappings.edit, {",
            "+                keys = keys,",
            "+                description = descriptions[name],",
            "+                action = keymap_command_map.edit[keys],",
            "+            })",
            "+        end",
            "     end",
            "+",
            "+    return mappings",
            " end",
            " ",
            " ---@return integer -- bufnr",
            " function M.render()",
            '-    local bufnr = require("trunks._ui.popups.popup").render_popup({',
            '-        ui_type = "commit_popup",',
            '+    local bufnr = require("trunks._ui.elements").new_buffer({',
            '         buffer_name = "TrunksCommitPopup",',
            '-        title = "Commit",',
            '+        win_config = { split = "below" },',
            "+    })",
            "+",
            '+    local maps = get_keymaps_with_descriptions(bufnr, "commit_popup")',
            "+    popup.render(bufnr, {",
            '+        { title = "Commit", rows = maps.basic },',
            '+        { title = "Edit", rows = maps.edit },',
            "     })",
            "-    set_keymaps(bufnr)",
            "     return bufnr",
            " end",
            " ",
        })

        local expected = {
            filename = "lua/trunks/_ui/popups/commit_popup.lua",
            line_nums = { 3, 6, 10, 14, 26, 43, 49, 51, 58 },
        }
        assert.are.same(expected.filename, result[1].filename)
        assert.are.same(
            expected.line_nums,
            vim.tbl_map(function(line)
                return line.line_num
            end, result[1].lines)
        )
    end)

    it("uses the correct filename for hunks that have lines that start with --- or +++", function()
        local result = parse_diff_output({
            "diff --git c/lua/trunks/_ui/popups/commit_popup.lua w/lua/trunks/_ui/popups/commit_popup.lua",
            "index 8b6683f..e82e9f7 100644",
            "--- c/filename.txt",
            "+++ w/filename.txt",
            "@@ -1,35 +1,61 @@",
            " local M = {}",
            "----@param bufnr integer",
            "++++@param bufnr integer",
        })

        assert.are.equal("filename.txt", result[1].filename)
    end)
end)
