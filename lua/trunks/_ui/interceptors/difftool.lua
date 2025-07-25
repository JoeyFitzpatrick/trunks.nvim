---@class trunks.DiffLineData
---@field filename string
---@field safe_filename string

local M = {}

---@param cmd string
---@return string
function M._get_commits_to_diff(cmd)
    local commits = ""
    local cmd_args = vim.tbl_filter(function(cmd_arg)
        return cmd_arg:sub(1, 1) ~= "-"
    end, vim.split(cmd, " "))
    if #cmd_args >= 2 then
        commits = cmd_args[2]
    end
    if commits ~= "" and not commits:match("%.%.") then
        commits = commits .. "..HEAD"
    end
    return commits
end

---@param commits_to_diff string
---@return string[]
local function get_diff_files(commits_to_diff)
    local diff_cmd = string.format("diff --name-status %s", commits_to_diff)
    local diff_stat_cmd = diff_cmd:gsub("%-%-name%-status", "--numstat", 1)
    local diff_files = require("trunks._core.run_cmd").run_cmd(diff_cmd)
    local diff_stats = require("trunks._core.run_cmd").run_cmd(diff_stat_cmd)
    if #diff_files ~= #diff_stats then
        error("Unable to parse diff stats")
    end
    local diff_files_with_stats = {}
    for i = 1, #diff_files do
        local file_with_status = diff_files[i]
        local diff_stat = diff_stats[i]
        local status = file_with_status:sub(1, 1)
        local filename = file_with_status:match("%S+$")
        local lines_added = diff_stat:match("%S+")
        local lines_removed = diff_stat:match("%s(%S+)")
        table.insert(diff_files_with_stats, string.format("%s %s %d, %d", status, filename, lines_added, lines_removed))
    end
    return diff_files_with_stats
end

--- Highlight difftool lines
---@param bufnr integer
local function highlight(bufnr)
    local highlight_line = require("trunks._ui.highlight").highlight_line
    for i, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
        local line_num = i - 1
        local status_start, status_end = 1, 2
        highlight_line(bufnr, "Keyword", line_num, status_start, status_end)
        local lines_added_start, lines_added_end = line:find("(%d+),", status_end + 1)
        highlight_line(bufnr, "Added", line_num, lines_added_start, lines_added_end)
        if not lines_added_end then
            return
        end
        local lines_removed_start, lines_removed_end = line:find("%d+", lines_added_end + 1)
        highlight_line(bufnr, "Removed", line_num, lines_removed_start, lines_removed_end)
    end
end

---@param bufnr integer
---@param line_num? integer
---@return trunks.DiffLineData | nil
local function get_line(bufnr, line_num)
    line_num = line_num or vim.api.nvim_win_get_cursor(0)[1]
    local line = vim.api.nvim_buf_get_lines(bufnr, line_num - 1, line_num, false)[1]
    if line == "" then
        return nil
    end
    local filename = line:match("%S+", 3)
    return { filename = filename, safe_filename = "'" .. filename .. "'" }
end

---@param bufnr integer
---@param commits string
---@param open_type "tab" | "window" | "vertical" | "horizontal"
---@return { file_to_open: string, commit_to_use: string } | nil
local function open_file(bufnr, commits, open_type)
    local ok, line_data = pcall(get_line, bufnr)
    if not ok or not line_data then
        return
    end

    local file_to_open = line_data.filename
    if commits:match("%.") then
        commits = commits:match("%.%.(%S+)")
    end

    if not file_to_open or not commits then
        return nil
    end

    if open_type == "tab" then
        require("trunks._core.open_file").open_file_in_tab(file_to_open, commits)
    elseif open_type == "window" then
        require("trunks._core.open_file").open_file_in_current_window(file_to_open, commits)
    elseif open_type == "vertical" then
        require("trunks._ui.auto_display").close_auto_display(bufnr, "difftool")
        require("trunks._core.open_file").open_file_in_split(file_to_open, commits, "right")
    elseif open_type == "horizontal" then
        require("trunks._ui.auto_display").close_auto_display(bufnr, "difftool")
        require("trunks._core.open_file").open_file_in_split(file_to_open, commits, "below")
    end
end

---@param bufnr integer
---@param commits string
local function set_keymaps(bufnr, commits)
    local keymaps = require("trunks._ui.keymaps.base").get_keymaps(bufnr, "difftool", { open_file_keymaps = true })
    local keymap_opts = { noremap = true, silent = true, buffer = bufnr, nowait = true }
    local set = require("trunks._ui.keymaps.set").safe_set_keymap

    set("n", keymaps.open_in_current_window, function()
        open_file(bufnr, commits, "window")
    end, keymap_opts)

    set("n", keymaps.open_in_horizontal_split, function()
        open_file(bufnr, commits, "horizontal")
    end, keymap_opts)

    set("n", keymaps.open_in_new_tab, function()
        open_file(bufnr, commits, "tab")
    end, keymap_opts)

    set("n", keymaps.open_in_vertical_split, function()
        open_file(bufnr, commits, "vertical")
    end, keymap_opts)
end

---@param command_builder trunks.Command
M.render = function(command_builder)
    local bufnr = require("trunks._ui.elements").new_buffer({})
    local commits_to_diff = M._get_commits_to_diff(command_builder.base)

    require("trunks._ui.utils.buffer_text").set(bufnr, get_diff_files(commits_to_diff))
    highlight(bufnr)
    set_keymaps(bufnr, commits_to_diff)
    require("trunks._ui.auto_display").create_auto_display(bufnr, "difftool", {
        generate_cmd = function()
            local ok, line_data = pcall(get_line, bufnr)
            if not ok or not line_data then
                return
            end
            return string.format("git diff %s -- %s", commits_to_diff, line_data.safe_filename)
        end,
        get_current_diff = function()
            local ok, line_data = pcall(get_line, bufnr)
            if not ok or not line_data then
                return
            end
            return line_data.safe_filename
        end,
        strategy = { display_strategy = "below", win_size = 0.67 },
    })
end

return M
