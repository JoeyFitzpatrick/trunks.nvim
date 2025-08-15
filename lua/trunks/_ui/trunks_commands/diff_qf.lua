---@class trunks.DiffQfLine
---@field line_num integer
---@field text string

---@class trunks.DiffQfHunk
---@field bufnr integer
---@field filename string
---@field lines trunks.DiffQfLine[]

---@class trunks.DiffQfCommitRange
---@field left string
---@field right string

local M = {}

local WORKING_TREE = "working_tree"

local Command = require("trunks._core.command")

---@param filename? string
---@param commit_range? string
---@return integer -- bufnr of created buffer
local function create_buffer(filename, commit_range)
    if not filename then
        return -1
    end
    if not commit_range then
        commit_range = "HEAD"
    end

    local bufnr = require("trunks._core.open_file").open_file_hidden(filename, commit_range, {})
    return bufnr
end

---@param lines string[]
---@param commit_range? string
---@return trunks.DiffQfHunk[]
function M._parse_diff_output(lines, commit_range)
    local qf_locations = {}
    local function get_initial_state()
        return {
            filename = nil,
            lines = {},
            start_line = nil,
            num_lines_since_start = 0,
            should_use_line = true,
            hunk_added_lines = false,
            finalized_line_num = false,
        }
    end
    local state = get_initial_state()

    for i, line in ipairs(lines) do
        if vim.startswith(line, "diff") and i ~= 1 then
            table.insert(qf_locations, {
                filename = state.filename,
                bufnr = create_buffer(state.filename, commit_range),
                lines = state.lines,
            })
            state = get_initial_state()
        elseif not state.start_line and (vim.startswith(line, "---") or vim.startswith(line, "+++")) then
            state.filename = line:sub(7) -- Everything after diff text, e.g. "--- a/"
        elseif vim.startswith(line, "@@") then
            state.start_line = tonumber(line:match("%+(%d+)"))
            state.num_lines_since_start = 0
        elseif state.start_line then
            local is_removed_line = vim.startswith(line, "-")
            local is_added_line = vim.startswith(line, "+")
            local is_changed_line = is_removed_line or is_added_line
            -- Only add first changed line in each group of changed lines.
            -- A hunk can have multiple groups of changed lines.
            if state.should_use_line and is_changed_line then
                table.insert(state.lines, { line_num = state.num_lines_since_start + state.start_line, text = line })
                state.should_use_line = false
                state.finalized_line_num = false
            elseif not is_changed_line then
                state.should_use_line = true

                if not state.finalized_line_num and not state.hunk_added_lines and #state.lines > 0 then
                    state.lines[#state.lines].line_num = state.lines[#state.lines].line_num - 1
                end
                state.finalized_line_num = true
                state.hunk_added_lines = false
            end

            if not is_removed_line then
                state.num_lines_since_start = state.num_lines_since_start + 1
            end

            if is_added_line then
                state.hunk_added_lines = true
            end
        end
    end
    if #state.lines > 0 then
        table.insert(qf_locations, {
            filename = state.filename,
            bufnr = create_buffer(state.filename, commit_range),
            lines = state.lines,
        })
    end
    return qf_locations
end

---@param commit_range? string
local function get_qf_locations(commit_range)
    local cmd = commit_range and ("diff " .. commit_range) or "diff"
    local command_builder = Command.base_command(cmd)
    local diff_output = require("trunks._core.run_cmd").run_cmd(command_builder)

    return M._parse_diff_output(diff_output, commit_range)
end

---@return string[]
local function format_qf(info)
    local result = {}
    local items = vim.fn.getqflist({ id = info.id, items = 0 }).items

    local max_filename_length = 0
    local max_line_num = 0
    for _, item in ipairs(items) do
        max_filename_length = math.max(max_filename_length, #item.user_data.filename)
        max_line_num = math.max(max_line_num, item.lnum)
    end
    max_line_num = #tostring(max_line_num)

    for _, item in ipairs(items) do
        local num_digits = #tostring(item.lnum)
        table.insert(
            result,
            string
                .format(
                    "%s%s ┃%s%d┃ %s",
                    item.user_data.filename,
                    string.rep(" ", max_filename_length - #item.user_data.filename),
                    string.rep(" ", max_line_num - num_digits),
                    item.lnum,
                    item.text:match(".?%s*(.+)")
                )
                :sub(1, vim.o.columns - 12)
        )
    end

    return result
end

local function highlight_qf_buffer(bufnr)
    vim.api.nvim_buf_call(bufnr, function()
        vim.cmd([[
            syntax clear
            syntax match Function /^\S\+/
            syntax match Comment /┃\zs[^┃]*\ze┃/
        ]])
    end)
end

local function set_to_head_if_empty(str)
    if not str or str == "" then
        return "HEAD"
    end
    return str
end

--- This returns a table like `{ left = commit_a, right = commit_b }`.
--- `left` is the commit used for the left side, and is considered the "home" commit.
--- It can also be the working tree.
--- `right` is the commit used for the split off of the `left` commit, and is to the right.
---@param commit_range? string
---@return trunks.DiffQfCommitRange
function M._parse_commit_range(commit_range)
    if not commit_range then
        return { left = WORKING_TREE, right = "HEAD" }
    end

    local delimiter = ".."
    local commit_range_marker = commit_range:find(delimiter, 1, true)
    if not commit_range_marker then
        delimiter = " "
        commit_range_marker = commit_range:find(delimiter, 1, true)
    end
    if commit_range_marker then
        local commits = vim.split(commit_range, delimiter, { plain = true })
        local left = set_to_head_if_empty(commits[1])
        local right = set_to_head_if_empty(commits[2])
        return { left = left, right = right }
    end

    if commit_range:match("^%S+$") then
        return { left = WORKING_TREE, right = commit_range }
    end
end

---@param commit_range? string
function M.render(commit_range)
    local qf_locations = get_qf_locations(commit_range)
    local flattened_qf_locations = {}

    for _, location in ipairs(qf_locations) do
        for _, line in ipairs(location.lines) do
            table.insert(flattened_qf_locations, {
                filename = location.filename,
                bufnr = location.bufnr,
                lnum = line.line_num,
                text = line.text,
                user_data = { filename = location.filename },
            })
        end
    end

    vim.fn.setqflist({}, "r", {
        title = "Trunks diff-qf",
        items = flattened_qf_locations,
        quickfixtextfunc = format_qf,
    })
    vim.cmd.copen()
    highlight_qf_buffer(vim.api.nvim_get_current_buf())
end

return M
