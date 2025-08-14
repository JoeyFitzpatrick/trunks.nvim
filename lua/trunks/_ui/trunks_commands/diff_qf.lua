---@class trunks.DiffQfHunk
---@field bufnr integer
---@field filename string
---@field line_nums integer[]

local M = {}

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
            line_nums = {},
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
                line_nums = state.line_nums,
            })
            state = get_initial_state()
        elseif vim.startswith(line, "---") or vim.startswith(line, "+++") then
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
                table.insert(state.line_nums, state.num_lines_since_start + state.start_line)
                state.should_use_line = false
                state.finalized_line_num = false
            elseif not is_changed_line then
                state.should_use_line = true

                if not state.finalized_line_num and not state.hunk_added_lines and #state.line_nums > 0 then
                    state.line_nums[#state.line_nums] = state.line_nums[#state.line_nums] - 1
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
    if #state.line_nums > 0 then
        table.insert(qf_locations, {
            filename = state.filename,
            bufnr = create_buffer(state.filename, commit_range),
            line_nums = state.line_nums,
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

---@param commit_range? string
function M.render(commit_range)
    local qf_locations = get_qf_locations(commit_range)
    local flattened_qf_locations = {}

    for _, location in ipairs(qf_locations) do
        for _, line_num in ipairs(location.line_nums) do
            table.insert(
                flattened_qf_locations,
                { filename = location.filename, bufnr = location.bufnr, lnum = line_num }
            )
        end
    end

    vim.fn.setqflist(flattened_qf_locations)
    vim.cmd.copen()
end

return M
