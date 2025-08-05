---@class trunks.DiffQfHunk
---@field filename string
---@field line_nums integer[]

local M = {}

local Command = require("trunks._core.command")

---@param line string
---@return string | nil
local function parse_filename(line)
    if vim.startswith(line, "---") or vim.startswith(line, "+++") then
        return line:sub(7) -- Everything after diff text, e.g. "--- a/"
    end
    return nil
end

---@param hunk string[]
---@param filename? string
---@return trunks.DiffQfHunk
function M._parse_diff_line(hunk, filename)
    local i = 1

    -- Before "@@" line
    while not vim.startswith(hunk[i], "@@") do
        if not filename then
            filename = parse_filename(hunk[i])
        end
        i = i + 1
    end

    -- At "@@" line
    local start_line = tonumber(hunk[i]:match("%+(%d+)"))
    i = i + 1

    -- After @@ line
    local line_nums = {}
    local num_lines_since_start = 0
    local should_use_line = true
    while i <= #hunk do
        local line = hunk[i]
        local is_changed_line = vim.startswith(line, "-") or vim.startswith(line, "+")

        -- Only add first changed line in each group of changed lines.
        -- A hunk can have multiple groups of changed lines.
        if should_use_line and is_changed_line then
            table.insert(line_nums, num_lines_since_start + start_line)
            should_use_line = false
        elseif not is_changed_line then
            should_use_line = true
        end

        i = i + 1
        num_lines_since_start = num_lines_since_start + 1
    end
    return { filename = filename, line_nums = line_nums }
end

---@param commit_range? string
local function get_qf_locations(commit_range)
    local cmd = commit_range and ("diff " .. commit_range) or "diff"
    local command_builder = Command.base_command(cmd)

    local locations = {}
    vim.fn.jobstart(command_builder:build(), {
        on_stdout = function(_, data, _)
            if data then
                for i, line in ipairs(data) do
                end
            end
        end,
    })
end

---@param commit_range? string
function M.render(commit_range)
    get_qf_locations(commit_range)
end

return M
