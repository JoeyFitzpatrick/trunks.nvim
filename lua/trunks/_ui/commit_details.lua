---@class trunks.CommitDetailsLineData
---@field filename string
---@field safe_filename string

---@class trunks.CommitDetailsRenderOpts
---@field is_stash? boolean
---@field filename? string

local M = {}

---@param bufnr integer
---@param i integer
---@param line string
local function highlight_line(bufnr, i, line)
    local start = line:find("|")
    if not start then
        return
    end
    local num_lines_changed_start, num_lines_changed_end = line:find("%d+", start)
    require("trunks._ui.highlight").highlight_line(
        bufnr,
        "Keyword",
        i - 1,
        num_lines_changed_start,
        num_lines_changed_end
    )
    local hl_groups = require("trunks._constants.highlight_groups").highlight_groups
    local plus_start, plus_end = line:find("%++", start)
    require("trunks._ui.highlight").highlight_line(bufnr, hl_groups.TRUNKS_DIFF_ADD, i - 1, plus_start, plus_end)
    local minus_start, minus_end = line:find("%-+", start)
    require("trunks._ui.highlight").highlight_line(bufnr, hl_groups.TRUNKS_DIFF_REMOVE, i - 1, minus_start, minus_end)
end

--- This changes the table in place instead of returning a new table
---@param commit_data string[]
local function move_commit_stats_above_files(commit_data)
    local commit_stats = commit_data[#commit_data]
    for i, line in ipairs(commit_data) do
        if line:match("^%s%S") then
            table.insert(commit_data, i, commit_stats)
            table.remove(commit_data, #commit_data)
            return
        end
    end
end

---@param bufnr integer
---@param commit string
---@param opts trunks.CommitDetailsRenderOpts
function M.set_lines(bufnr, commit, opts)
    local commit_data = {}
    if opts.is_stash then
        local commit_info_command_builder = require("trunks._core.command").base_command("log -n 1 " .. commit)
        local commit_info = require("trunks._core.run_cmd").run_cmd(commit_info_command_builder)
        for _, line in ipairs(commit_info) do
            table.insert(commit_data, line)
        end
        table.insert(commit_data, "")

        local commit_stats_command_builder =
            require("trunks._core.command").base_command("stash show -u --stat=10000 --stat-graph-width=40 " .. commit)
        local commit_stats = require("trunks._core.run_cmd").run_cmd(commit_stats_command_builder)
        for _, line in ipairs(commit_stats) do
            table.insert(commit_data, line)
        end
    else
        local command_builder =
            require("trunks._core.command").base_command("show --stat=10000 --stat-graph-width=40 " .. commit)

        commit_data = require("trunks._core.run_cmd").run_cmd(command_builder)
    end

    move_commit_stats_above_files(commit_data)
    local set_lines = require("trunks._ui.utils.buffer_text").set
    set_lines(bufnr, commit_data)

    for i, line in ipairs(commit_data) do
        highlight_line(bufnr, i, line)
    end
    for i, line in ipairs(commit_data) do
        if line:match("^%s%S") then
            vim.api.nvim_win_set_cursor(0, { i + 1, 0 })
            return
        end
    end

    -- If no files found to set cursor to, the commit is empty and we want to be explicit
    set_lines(bufnr, { "", "(Empty commit)" }, #commit_data, #commit_data)
end

---@param bufnr integer
---@param line_num? integer
---@return trunks.CommitDetailsLineData | nil
function M.get_line(bufnr, line_num)
    line_num = line_num or vim.api.nvim_win_get_cursor(0)[1]

    -- Commits have a structure like this:
    --"commit ea8a7c50e380d5d6e09dd69562f73c6242e27401",
    --"",
    --"    feat: fix diff and show commands",
    --"",
    --" 4 files changed, 6 insertions(+), 397 deletions(-)",
    --" lua/trunks/_constants/command_strategies.lua         |   4 +-",
    --
    -- We can check if a given line is a file by seeing if there are any whitespace-only
    -- lines from the bottom of the file to the line we're on. But the "4 files changed"
    -- line would also pass this check, so we also need to check the line before the current line.
    local line_before_zero_indexed_line_num = math.max(line_num - 2, 0)
    local lines = vim.api.nvim_buf_get_lines(bufnr, line_before_zero_indexed_line_num, -1, false)
    for i = #lines, 1, -1 do
        if lines[i] == "" then
            return nil
        end
    end

    local line = lines[2]
    local filename = line:match("^.(%S+)", 1)
    if not filename then
        return nil
    end
    return { filename = filename, safe_filename = "'" .. filename .. "'" }
end

---@param bufnr integer
---@param commit string
local function set_keymaps(bufnr, commit)
    local keymap_opts = { noremap = true, silent = true, buffer = bufnr, nowait = true }
    local keymaps = require("trunks._ui.keymaps.base").get_keymaps(
        bufnr,
        "commit_details",
        { open_file_keymaps = true, auto_display_keymaps = true }
    )
    local set = require("trunks._ui.keymaps.set").safe_set_keymap

    require("trunks._ui.keymaps.set").set_q_keymap(bufnr)

    set("n", keymaps.edit_file, function()
        local ok, line_data = pcall(M.get_line, bufnr)
        if not ok or not line_data then
            return
        end
        if vim.uv.fs_stat(line_data.filename) then
            require("trunks._core.register").deregister_buffer(bufnr, {})
            vim.cmd.edit(line_data.filename)
        else
            vim.notify("File does not exist: " .. line_data.filename, vim.log.levels.ERROR)
        end
    end, { buffer = bufnr })

    set("n", keymaps.restore_popup, function()
        local ok, line_data = pcall(M.get_line, bufnr)
        if not ok or not line_data then
            return
        end
        require("trunks._ui.popups.restore_popup").render(line_data.filename, commit)
    end, { buffer = bufnr })

    set("n", keymaps.open_in_current_window, function()
        local ok, line_data = pcall(M.get_line, bufnr)
        if not ok or not line_data then
            return
        end
        require("trunks._core.open_file").open_file_in_current_window(line_data.filename, commit, {})
    end, keymap_opts)

    set("n", keymaps.open_in_horizontal_split, function()
        local ok, line_data = pcall(M.get_line, bufnr)
        if not ok or not line_data then
            return
        end
        require("trunks._ui.auto_display").close_auto_display(bufnr, "commit_details")
        require("trunks._core.open_file").open_file_in_split(line_data.filename, commit, "below", {})
    end, keymap_opts)

    set("n", keymaps.open_in_new_tab, function()
        local ok, line_data = pcall(M.get_line, bufnr)
        if not ok or not line_data then
            return
        end
        require("trunks._core.open_file").open_file_in_tab(line_data.filename, commit, {})
    end, keymap_opts)

    set("n", keymaps.open_in_vertical_split, function()
        local ok, line_data = pcall(M.get_line, bufnr)
        if not ok or not line_data then
            return
        end
        require("trunks._ui.auto_display").close_auto_display(bufnr, "commit_details")
        require("trunks._core.open_file").open_file_in_split(line_data.filename, commit, "right", {})
    end, keymap_opts)

    set("n", keymaps.show_all_changes, function()
        vim.cmd("G show " .. commit)
    end, keymap_opts)
end

---@param bufnr integer
---@param win integer
---@param filename string
local function set_cursor_to_filename(bufnr, win, filename)
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    for i, line in ipairs(lines) do
        if line:match("^%s*" .. vim.pesc(filename)) then
            pcall(vim.api.nvim_win_set_cursor, win, { i, 0 })
            return
        end
    end
end

---@param commit string
---@param opts trunks.CommitDetailsRenderOpts
function M.render(commit, opts)
    local bufnr, win = require("trunks._ui.elements").new_buffer({ filetype = "git", show = true })
    M.set_lines(bufnr, commit, opts)

    require("trunks._ui.auto_display").create_auto_display(bufnr, "commit_details", {
        generate_cmd = function()
            local ok, line_data = pcall(M.get_line, bufnr)
            if not ok or not line_data then
                return
            end

            local Command = require("trunks._core.command")
            local command_builder

            if opts.is_stash then
                -- Diffs for stashed files require different approaches,
                -- depending on whether the file was tracked or untracked.
                local diff_output = require("trunks._core.run_cmd").run_cmd(
                    string.format("git diff %s^1 %s -- %s", commit, commit, line_data.safe_filename)
                )
                if #diff_output > 0 then
                    return string.format("git diff %s^1 %s -- %s", commit, commit, line_data.safe_filename)
                else
                    -- If there is no output, the file might be untracked,
                    -- which requires diffing against different parent.
                    return string.format("git diff %s %s^3 -- %s", commit, commit, line_data.safe_filename)
                end
            else
                -- The -m flag diffs both merge commits and normal commits.
                -- Empty pretty format omits commit message, and everything aside from the diff itself.
                command_builder =
                    Command.base_command("show -m --pretty=format:'' " .. commit .. " -- " .. line_data.safe_filename)
            end

            return command_builder:build()
        end,
        get_current_diff = function()
            local ok, line_data = pcall(M.get_line, bufnr)
            if not ok or not line_data then
                return
            end
            return line_data.filename
        end,
        strategy = { display_strategy = "below", win_size = 0.67, insert = false, enter = false },
    })

    if opts.filename then
        set_cursor_to_filename(bufnr, win, opts.filename)
    end

    set_keymaps(bufnr, commit)
    require("trunks._ui.keymaps.keymaps_text").show_in_cmdline(bufnr, { "commit_details" })
end

return M
