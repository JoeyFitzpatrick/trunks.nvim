-- Commit details

---@class trunks.CommitDetailsLineData
---@field filename string
---@field safe_filename string

---@class trunks.CommitDetailsRenderOpts
---@field is_stash? boolean

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

---@param bufnr integer
---@param commit string
function M.set_lines(bufnr, commit)
    if not vim.api.nvim_buf_is_valid(bufnr) then
        return
    end

    vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
    local command_builder =
        require("trunks._core.command").base_command("show --stat=10000 --stat-graph-width=40 " .. commit)
    local commit_data = require("trunks._core.run_cmd").run_cmd(command_builder)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, commit_data)
    vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })

    for i, line in ipairs(commit_data) do
        highlight_line(bufnr, i, line)
    end
    for i, line in ipairs(commit_data) do
        if line:match("^%s%S") then
            vim.api.nvim_win_set_cursor(0, { i, 0 })
            return
        end
    end
end

---@param bufnr integer
---@param line_num? integer
---@return trunks.CommitDetailsLineData | nil
function M.get_line(bufnr, line_num)
    line_num = line_num or vim.api.nvim_win_get_cursor(0)[1]
    local line = vim.api.nvim_buf_get_lines(bufnr, line_num - 1, line_num, false)[1]
    local filename = line:match("%S+", 1)
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

    set("n", keymaps.open_in_current_window, function()
        local ok, line_data = pcall(M.get_line, bufnr)
        if not ok or not line_data then
            return
        end
        require("trunks._core.open_file").open_file_in_current_window(line_data.filename, commit)
    end, keymap_opts)

    set("n", keymaps.open_in_horizontal_split, function()
        local ok, line_data = pcall(M.get_line, bufnr)
        if not ok or not line_data then
            return
        end
        require("trunks._ui.auto_display").close_auto_display(bufnr, "commit_details")
        require("trunks._core.open_file").open_file_in_split(line_data.filename, commit, "below")
    end, keymap_opts)

    set("n", keymaps.open_in_new_tab, function()
        local ok, line_data = pcall(M.get_line, bufnr)
        if not ok or not line_data then
            return
        end
        require("trunks._core.open_file").open_file_in_tab(line_data.filename, commit)
    end, keymap_opts)

    set("n", keymaps.open_in_vertical_split, function()
        local ok, line_data = pcall(M.get_line, bufnr)
        if not ok or not line_data then
            return
        end
        require("trunks._ui.auto_display").close_auto_display(bufnr, "commit_details")
        require("trunks._core.open_file").open_file_in_split(line_data.filename, commit, "right")
    end, keymap_opts)

    set("n", keymaps.show_all_changes, function()
        vim.cmd("G show " .. commit)
    end, keymap_opts)
end

---@param commit string
---@param opts trunks.CommitDetailsRenderOpts
function M.render(commit, opts)
    local bufnr = require("trunks._ui.elements").new_buffer({ filetype = "git" })
    M.set_lines(bufnr, commit)
    require("trunks._ui.auto_display").create_auto_display(bufnr, "commit_details", {
        generate_cmd = function()
            local ok, line_data = pcall(M.get_line, bufnr)
            if not ok or not line_data then
                return
            end

            local Command = require("trunks._core.command")
            local command_builder

            if opts.is_stash then
                command_builder =
                    Command.base_command(string.format("diff %s^1 %s -- %s", commit, commit, line_data.safe_filename))
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
    set_keymaps(bufnr, commit)
end

return M
