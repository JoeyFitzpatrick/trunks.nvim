local M = {}

local status_utils = require("trunks._ui.home_options.status.status_utils")
local run_hidden_cmd = require("trunks._core.run_cmd").run_hidden_cmd
local run_cmd = require("trunks._core.run_cmd").run_cmd
local Command = require("trunks._core.command")

local function get_status(line)
    return line:sub(1, 2)
end

local SECTIONS = {
    STAGED = "Staged",
    UNSTAGED = "Unstaged",
}

---@class trunks.StatusLineData
---@field filename string
---@field safe_filename string
---@field status string
---@field staged boolean

---@param bufnr integer
---@param line_num? integer
---@return trunks.StatusLineData | nil
function M.get_line(bufnr, line_num)
    line_num = line_num or vim.api.nvim_win_get_cursor(0)[1]
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local staged = false

    local current_line = lines[line_num]
    if current_line:find("^[%+%-@ ]") then
        for i = line_num, 1, -1 do
            if not lines[i]:find("^[%+%-@ ]") then
                line_num = i
                break
            end
        end
    end

    if line_num == 1 then
        return nil
    end
    -- Walk backwards to see which section we're in, if any
    for i = line_num - 1, 1, -1 do
        local line = lines[i]
        local is_staged_section = vim.startswith(line, SECTIONS.STAGED)
        local is_unstaged_section = vim.startswith(line, SECTIONS.UNSTAGED)
        if is_staged_section or is_unstaged_section then
            staged = is_staged_section
            break
        end
        -- If no section found, we're not on a file. Return nil.
        if i == 1 then
            return nil
        end
    end

    local split_line = vim.split(lines[line_num], " ")
    local status = split_line[1]
    local filename = split_line[2]
    local safe_filename = require("trunks._core.texter").surround_with_quotes(filename)

    return {
        filename = filename,
        safe_filename = safe_filename,
        status = status,
        staged = staged,
    }
end

local function remove_untracked_file(filename)
    run_hidden_cmd("git clean -f " .. filename, { rerender = true })

    -- File/dir can still exist in some edge cases, for example, if it's an empty dir with a .git folder.
    -- In this case, currently we no-op, but documenting here for future reference.
end

---@param bufnr integer
---@param status_file trunks.StatusLineData
function M._toggle_inline_diff(bufnr, status_file) end

---@param bufnr integer
function M.set_keymaps(bufnr)
    local keymaps = require("trunks._ui.keymaps.base").get_keymaps(bufnr, "status", { auto_display_keymaps = true })
    local keymap_opts = { noremap = true, silent = true, buffer = bufnr, nowait = true }
    local set = require("trunks._ui.keymaps.set").safe_set_keymap
    local with_line = require("trunks._ui.keymaps.set").with_line

    set(
        "n",
        keymaps.stage,
        with_line(bufnr, M.get_line, function(line_data)
            if not line_data.staged then
                run_hidden_cmd("git add -- " .. line_data.filename, { rerender = true })
            else
                run_hidden_cmd("git reset HEAD -- " .. line_data.filename, { rerender = true })
            end
        end),
        keymap_opts
    )

    set("v", keymaps.stage, function()
        local visual_start_line, end_line = require("trunks._ui.utils.ui_utils").get_visual_line_nums()
        local files_to_stage = {}
        local status_files = vim.b[bufnr].trunks_status_files
        local should_stage = false
        for i = visual_start_line, end_line do
            local file = status_files[i]
            if file and file ~= vim.NIL then
                table.insert(files_to_stage, file)
                if not file.staged then
                    should_stage = true
                end
            end
        end
        local files_as_string = ""
        for i, file in ipairs(files_to_stage) do
            -- don't add space for first file, and don't include status
            files_as_string = files_as_string .. (i == 0 and "" or " ") .. file.filename
        end
        if should_stage then
            run_hidden_cmd("git add " .. files_as_string, { rerender = true })
            return
        end
        run_hidden_cmd("git restore --staged -- " .. files_as_string, { rerender = true })
    end, keymap_opts)

    set("n", keymaps.stage_all, function()
        local status_files = vim.b[bufnr].trunks_status_files
        for _, file in pairs(status_files.unstaged) do
            if file then
                run_hidden_cmd("git add -A", { rerender = true })
                return
            end
        end
        run_hidden_cmd("git reset", { rerender = true })
    end, keymap_opts)

    local keymap_to_command_map = {
        { keymap = keymaps.pull, command = "pull" },
    }

    for _, mapping in ipairs(keymap_to_command_map) do
        set("n", mapping.keymap, function()
            vim.wait(2000, function()
                return not vim.b.trunks_fetch_running
            end)
            vim.cmd("G " .. mapping.command)
        end, keymap_opts)
    end

    set("n", keymaps.commit_popup, function()
        require("trunks._ui.popups.commit_popup").render()
    end, keymap_opts)

    set(
        "n",
        keymaps.diff_file,
        with_line(bufnr, M.get_line, function(line_data)
            if line_data.status == "D" then
                vim.cmd("G diff HEAD -- " .. line_data.filename)
            else
                vim.cmd("G diff " .. line_data.filename)
            end
        end),
        keymap_opts
    )

    set(
        "n",
        keymaps.edit_file,
        with_line(bufnr, M.get_line, function(line_data)
            local current_buffer = vim.api.nvim_get_current_buf()
            -- Deregister current buffer so it doesn't hang around
            require("trunks._core.register").close_buffer(current_buffer)

            -- Home UI opens in new tab. If we're in a separate tab, close it.
            local num_tabs = #vim.api.nvim_list_tabpages()
            if num_tabs > 1 then
                vim.cmd("tabclose")
            end
            vim.api.nvim_exec2("e " .. line_data.filename, {})
        end),
        keymap_opts
    )

    set("n", keymaps.push, require("trunks._ui.keymaps.base").git_push_keymap, keymap_opts)

    set("n", keymaps.restore, function()
        -- We need to pass in line_num, otherwise it uses cursor position from popup
        local line_num = vim.api.nvim_win_get_cursor(0)[1]
        require("trunks._ui.popups.popup").render_popup({
            buffer_name = "TrunksStatusDeletePopup",
            title = "Git Restore Type",
            mappings = {
                {
                    keys = "f",
                    description = "Just this file",
                    action = function()
                        local ok, line_data = pcall(M.get_line, bufnr, line_num)
                        if not ok or not line_data then
                            return
                        end
                        local filename = line_data.safe_filename
                        local status = line_data.status
                        local status_checks = require("trunks._core.git")
                        if status_checks.is_untracked(status) then
                            remove_untracked_file(filename)
                        else
                            local cmd = "git reset -- " .. filename .. " && git restore -- " .. filename
                            run_hidden_cmd(cmd, { rerender = true })
                        end
                    end,
                },
                {
                    keys = "u",
                    description = "Unstaged changes for this file",
                    action = function()
                        local ok, line_data = pcall(M.get_line, bufnr, line_num)
                        if not ok or not line_data then
                            return
                        end
                        local filename = line_data.safe_filename
                        local status = line_data.status
                        local status_checks = require("trunks._core.git")
                        if status_checks.is_untracked(status) then
                            remove_untracked_file(filename)
                        else
                            -- Worth noting that lazygit does git -c core.hooksPath=/dev/null checkout -- filename
                            local cmd = "git restore -- " .. filename
                            run_hidden_cmd(cmd, { rerender = true })
                        end
                    end,
                },
                {
                    keys = "n",
                    description = "Nuke working tree",
                    action = function()
                        run_hidden_cmd("git reset --hard HEAD && git clean -fd", { rerender = true })
                    end,
                },
                {
                    keys = "h",
                    description = "Hard reset",
                    action = function()
                        run_hidden_cmd("git reset --hard HEAD", { rerender = true })
                    end,
                },
                {
                    keys = "s",
                    description = "Soft reset",
                    action = function()
                        run_hidden_cmd("git reset --soft HEAD", { rerender = true })
                    end,
                },
                {
                    keys = "m",
                    description = "Mixed reset",
                    action = function()
                        run_hidden_cmd("git reset --mixed HEAD", { rerender = true })
                    end,
                },
            },
        })
    end, keymap_opts)

    set("v", keymaps.restore, function()
        local visual_start_line, end_line = require("trunks._ui.utils.ui_utils").get_visual_line_nums()
        local files = vim.api.nvim_buf_get_lines(bufnr, visual_start_line, end_line, false)
        local statuses = {
            staged = "",
            unstaged = "",
            untracked = "",
        }
        for _, file in ipairs(files) do
            local status_to_use
            local status = get_status(file)
            if require("trunks._core.git").is_staged(status) then
                status_to_use = "staged"
            elseif require("trunks._core.git").is_untracked(status) then
                status_to_use = "untracked"
            else
                status_to_use = "unstaged"
            end
            local current_files = statuses[status_to_use]
            -- don't add space for first file, and don't include status
            statuses[status_to_use] = current_files .. (current_files == "" and "" or " ") .. file:sub(4)
        end
        vim.ui.select({ "Yes", "No" }, { prompt = "Restore (remove) all selected files?" }, function(choice)
            if choice ~= "Yes" then
                return
            end
            if statuses.staged ~= "" then
                run_hidden_cmd(
                    string.format("git reset -- %s && git clean -f -- %s", statuses.staged, statuses.staged),
                    { rerender = true }
                )
            end
            if statuses.unstaged ~= "" then
                run_hidden_cmd("git restore -- " .. statuses.unstaged, { rerender = true })
            end
            if statuses.untracked ~= "" then
                run_hidden_cmd("git clean -f -- " .. statuses.untracked, { rerender = true })
            end
        end)
    end, keymap_opts)

    set("n", keymaps.stash_popup, function()
        require("trunks._ui.popups.stash_popup").render()
    end, keymap_opts)

    set(
        "n",
        "<S-Tab>",
        with_line(bufnr, M.get_line, function(line_data)
            if require("trunks._core.git").is_modified(line_data.status) then
                require("trunks._ui.auto_display").refresh(bufnr)
            end
        end),
        keymap_opts
    )
end

---@param line_data trunks.StatusLineData
---@return string
local function get_diff_cmd(line_data)
    local status = line_data.status
    local safe_filename = line_data.safe_filename
    local is_staged = line_data.staged

    local is_untracked = status == "?"
    if is_untracked then
        return "diff --no-index /dev/null -- " .. safe_filename
    end

    if is_staged then
        return "diff --staged -- " .. safe_filename
    end

    local is_modified = status == "M"
    if is_modified then
        return "diff -- " .. safe_filename
    end

    return "diff -- " .. safe_filename
end

---@class trunks.StatusSetLinesContext
---@field get_files? fun(): string[]
---@field diff_stat_text? string
---@field remote_branch_text? string

---@param bufnr integer
---@param ctx? trunks.StatusSetLinesContext
function M._set_lines(bufnr, ctx)
    ctx = ctx or {}

    local index = 0
    ---@param lines string[]
    local set = function(lines)
        if lines == {} then
            return
        end
        require("trunks._ui.utils.buffer_text").set(bufnr, lines, index)
        index = index + #lines
    end

    local head_cmd = Command.base_command("symbolic-ref --short HEAD"):build()
    local head_cmd_output, head_cmd_exit_code = run_cmd(head_cmd)
    local branch

    if head_cmd_exit_code == 0 then
        branch = head_cmd_output[1]
        set({ "Head: " .. branch })
    else
        local hash_cmd = Command.base_command("rev-parse --short HEAD"):build()
        local hash_cmd_output, hash_cmd_exit_code = run_cmd(hash_cmd)
        if hash_cmd_output[1] and hash_cmd_exit_code == 0 then
            set(bufnr, { "Head: " .. hash_cmd_output[1] .. "(detached head)" })
        else
            set(bufnr, { "Head: unable to find current HEAD" })
        end
    end

    if branch then
        require("trunks._ui.utils.num_commits_pull_push").set_num_commits_to_pull_and_push(
            bufnr,
            { line_num = 0, branch = branch }
        )
    end

    local remote_branch_text = status_utils.get_remote_branch(ctx.remote_branch_text)
    set({ remote_branch_text }, 1)

    set({ "Help: g?" })

    local diff_stat_text = status_utils.get_diff_stat(ctx.diff_stat_text)
    set({ diff_stat_text })

    local files = status_utils.get_status_files(ctx.get_files)
    local unstaged_untracked_index
    if #files.unstaged_and_untracked > 0 then
        set({ "", string.format("Unstaged (%d)", #files.unstaged_and_untracked) })
        unstaged_untracked_index = index
        set(files.unstaged_and_untracked)
    end

    local staged_index
    if #files.staged > 0 then
        set({ "", string.format("Staged (%d)", #files.staged) })
        staged_index = index
        set(files.staged)
    end

    status_utils.set_status_files_variable(
        bufnr,
        { files = files, staged_index = staged_index, unstaged_untracked_index = unstaged_untracked_index }
    )
end

---@param bufnr integer
---@param opts trunks.UiRenderOpts
function M.render(bufnr, opts)
    vim.bo[bufnr].filetype = "trunks"
    require("trunks._ui.home_options.status")._set_lines(bufnr)
    require("trunks._ui.home_options.status").set_keymaps(bufnr)
    if opts.set_keymaps then
        opts.set_keymaps(bufnr)
    end

    local with_line = require("trunks._ui.keymaps.set").with_line

    require("trunks._ui.auto_display").create_auto_display(bufnr, "status", {
        generate_cmd = with_line(bufnr, M.get_line, function(line_data)
            local last_file = vim.b[bufnr].trunks_last_file
            if last_file ~= line_data.filename then
                vim.b[bufnr].trunks_last_file = line_data.filename
            end
            return Command.base_command(get_diff_cmd(line_data)):build()
        end),
        get_current_diff = with_line(bufnr, M.get_line, function(line_data)
            return line_data.safe_filename
        end),
        strategy = { enter = false, display_strategy = "below", pty = false },
    })

    require("trunks._ui.keymaps.keymaps_text").show_in_cmdline(bufnr, { "status", "home" })

    vim.b[bufnr].trunks_rerender_fn = function()
        if not vim.api.nvim_buf_is_valid(bufnr) then
            return
        end
        local win = vim.fn.bufwinid(bufnr)
        if not vim.api.nvim_win_is_valid(win) then
            return
        end
        local cursor = vim.api.nvim_win_get_cursor(win)
        vim.bo[bufnr].modifiable = true
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
        M._set_lines(bufnr)
        vim.bo[bufnr].modifiable = false
        vim.api.nvim_win_set_cursor(win, cursor)
    end
end

return M
