---@class trunks.StatusLineData
---@field filename string
---@field safe_filename string
---@field status string

local M = {}

local function get_status(line)
    return line:sub(1, 2)
end

---@param bufnr integer
---@param line_num? integer
---@return trunks.StatusLineData | nil
function M.get_line(bufnr, line_num)
    line_num = line_num or vim.api.nvim_win_get_cursor(0)[1]
    local line = vim.api.nvim_buf_get_lines(bufnr, line_num - 1, line_num, false)[1]
    if not line or not line:match("^%s?[%w%?]") then
        return nil
    end
    local filename = line:sub(4)
    return { filename = filename, safe_filename = "'" .. filename .. "'", status = get_status(line) }
end

local function remove_untracked_file(filename)
    require("trunks._core.run_cmd").run_hidden_cmd("git clean -f " .. filename, { rerender = true })

    -- File/dir can still exist in some edge cases, for example, if it's an empty dir with a .git folder.
    -- In this case, currently we no-op, but documenting here for future reference.
end

---@param bufnr integer
function M.set_keymaps(bufnr)
    local default_ui_keymap_opts = { auto_display_keymaps = true }
    local ui_keymap_opts = vim.tbl_extend("force", default_ui_keymap_opts, {})
    local keymaps = require("trunks._ui.keymaps.base").get_keymaps(bufnr, "status", ui_keymap_opts)
    local keymap_opts = { noremap = true, silent = true, buffer = bufnr, nowait = true }
    local set = require("trunks._ui.keymaps.set").safe_set_keymap

    set("n", keymaps.stage, function()
        local ok, line_data = pcall(M.get_line, bufnr)
        if not ok or not line_data then
            return
        end
        if not require("trunks._core.git").is_staged(line_data.status) then
            require("trunks._core.run_cmd").run_hidden_cmd("git add -- " .. line_data.filename, { rerender = true })
        else
            require("trunks._core.run_cmd").run_hidden_cmd(
                "git reset HEAD -- " .. line_data.filename,
                { rerender = true }
            )
        end
    end, keymap_opts)

    set("v", keymaps.stage, function()
        local visual_start_line, end_line = require("trunks._ui.utils.ui_utils").get_visual_line_nums()
        local files = vim.api.nvim_buf_get_lines(bufnr, visual_start_line, end_line, false)
        local should_stage = require("trunks._ui.home_options.status.status_utils").should_stage_files(files)
        local files_as_string = ""
        for i, file in ipairs(files) do
            -- don't add space for first file, and don't include status
            files_as_string = files_as_string .. (i == 0 and "" or " ") .. file:sub(4)
        end
        if should_stage then
            require("trunks._core.run_cmd").run_hidden_cmd("git add " .. files_as_string, { rerender = true })
            return
        end
        require("trunks._core.run_cmd").run_hidden_cmd(
            "git restore --staged -- " .. files_as_string,
            { rerender = true }
        )
    end, keymap_opts)

    set("n", keymaps.stage_all, function()
        local should_stage = require("trunks._ui.home_options.status.status_utils").should_stage_files(
            vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
        )
        if should_stage then
            require("trunks._core.run_cmd").run_hidden_cmd("git add -A", { rerender = true })
            return
        end
        require("trunks._core.run_cmd").run_hidden_cmd("git reset", { rerender = true })
    end, keymap_opts)

    local keymap_to_command_map = {
        { keymap = keymaps.pull, command = "pull" },
        { keymap = keymaps.push, command = "push" },
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

    set("n", keymaps.diff_file, function()
        local ok, line_data = pcall(M.get_line, bufnr)
        if not ok or not line_data then
            return
        end
        vim.api.nvim_exec2("G diff " .. line_data.filename, {})
    end, keymap_opts)

    set("n", keymaps.edit_file, function()
        local ok, line_data = pcall(M.get_line, bufnr)
        if not ok or not line_data then
            return
        end
        local current_buffer = vim.api.nvim_get_current_buf()
        -- Deregister current buffer so it doesn't hang around
        require("trunks._core.register").deregister_buffer(current_buffer)

        -- Home UI opens in new tab. If we're in a separate tab, close it.
        local num_tabs = #vim.api.nvim_list_tabpages()
        if num_tabs > 1 then
            vim.cmd("tabclose")
        end
        vim.api.nvim_exec2("e " .. line_data.filename, {})
    end, keymap_opts)

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
                            require("trunks._core.run_cmd").run_hidden_cmd(cmd, { rerender = true })
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
                            require("trunks._core.run_cmd").run_hidden_cmd(cmd, { rerender = true })
                        end
                    end,
                },
                {
                    keys = "n",
                    description = "Nuke working tree",
                    action = function()
                        require("trunks._core.run_cmd").run_hidden_cmd(
                            "git reset --hard HEAD && git clean -fd",
                            { rerender = true }
                        )
                    end,
                },
                {
                    keys = "h",
                    description = "Hard reset",
                    action = function()
                        require("trunks._core.run_cmd").run_hidden_cmd("git reset --hard HEAD", { rerender = true })
                    end,
                },
                {
                    keys = "s",
                    description = "Soft reset",
                    action = function()
                        require("trunks._core.run_cmd").run_hidden_cmd("git reset --soft HEAD", { rerender = true })
                    end,
                },
                {
                    keys = "m",
                    description = "Mixed reset",
                    action = function()
                        require("trunks._core.run_cmd").run_hidden_cmd("git reset --mixed HEAD", { rerender = true })
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
                require("trunks._core.run_cmd").run_hidden_cmd(
                    string.format("git reset -- %s && git clean -f -- %s", statuses.staged, statuses.staged),
                    { rerender = true }
                )
            end
            if statuses.unstaged ~= "" then
                require("trunks._core.run_cmd").run_hidden_cmd(
                    "git restore -- " .. statuses.unstaged,
                    { rerender = true }
                )
            end
            if statuses.untracked ~= "" then
                require("trunks._core.run_cmd").run_hidden_cmd(
                    "git clean -f -- " .. statuses.untracked,
                    { rerender = true }
                )
            end
        end)
    end, keymap_opts)

    set("n", keymaps.stash_popup, function()
        require("trunks._ui.popups.stash_popup").render()
    end, keymap_opts)
end

---@param status string
---@param filename string
---@return string
local function get_diff_cmd(status, filename)
    local status_checks = require("trunks._core.git")
    if status_checks.is_untracked(status) then
        return "diff --no-index /dev/null -- " .. filename
    end
    if status_checks.is_modified(status) then
        return string.format(
            "(echo '### STAGED CHANGES ###';"
                .. " git diff --cached -- %s;"
                .. " echo '\n### UNSTAGED CHANGES ###'; git diff -- %s)"
                .. " | $(git config --get core.pager || echo less)",
            filename,
            filename
        )
    end
    if status_checks.is_staged(status) then
        return "diff --staged -- " .. filename
    end
    if status_checks.is_deleted(status) then
        return "diff -- " .. filename
    end
    return "diff -- " .. filename
end

---@param bufnr integer
---@param opts? trunks.UiRenderOpts
---@return integer, integer -- bufnr, win
function M.render(bufnr, opts)
    opts = opts or {}
    local Command = require("trunks._core.command")

    local command_builder = Command.base_command("status -s --untracked")

    local term = require("trunks._ui.elements").terminal(
        bufnr,
        command_builder:build(),
        { enter = true, display_strategy = "full" }
    )

    local win = term.win
    require("trunks._ui.auto_display").create_auto_display(bufnr, "status", {
        generate_cmd = function()
            local ok, line_data = pcall(M.get_line, bufnr)
            if not ok or not line_data then
                return
            end
            return Command.base_command(get_diff_cmd(line_data.status, line_data.safe_filename)):build()
        end,
        get_current_diff = function()
            local ok, line_data = pcall(M.get_line, bufnr)
            if not ok or not line_data then
                return
            end
            return line_data.safe_filename
        end,
        strategy = { enter = false, display_strategy = "below", pty = false },
    })
    M.set_keymaps(bufnr)
    if opts.set_keymaps then
        opts.set_keymaps(bufnr)
    end

    require("trunks._ui.keymaps.keymaps_text").show_in_cmdline(bufnr, { "status" })

    require("trunks._core.autocmds").execute_user_autocmds({ ui_type = "buffer", ui_name = "status" })
    return bufnr, win
end

return M
