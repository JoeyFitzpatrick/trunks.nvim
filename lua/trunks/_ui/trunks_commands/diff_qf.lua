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

local Command = require("trunks._core.command")

---@param filename? string
---@param commit string
local function populate_file(filename, commit)
    if not filename then
        return nil
    end

    local augroup = vim.api.nvim_create_augroup("TrunksDiffQfHandler", { clear = false })
    vim.api.nvim_create_autocmd({ "BufWinEnter" }, {
        group = augroup,
        pattern = filename,
        once = true,
        callback = function(args)
            local bufnr = args.buf
            if not vim.b[bufnr].split_open then
                vim.cmd("only | copen | wincmd p")
                vim.cmd("Trunks vdiff " .. commit)
                vim.cmd("wincmd p")
                vim.b[bufnr].split_open = true
            else
                local wins = vim.fn.win_findbuf(bufnr)
                if #wins > 1 then
                    local cursor_pos = vim.api.nvim_win_get_cursor(0)
                    vim.api.nvim_win_close(0, true)
                    vim.api.nvim_win_set_cursor(0, cursor_pos)
                end
            end
        end,
        desc = "Trunks: open/close diff-qf splits",
    })

    return filename
end

---@param lines string[]
---@param commit? string
---@return trunks.DiffQfHunk[]
function M._parse_diff_output(lines, commit)
    commit = commit or "HEAD"
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
            local filename = populate_file(state.filename, commit)
            table.insert(qf_locations, {
                filename = filename,
                lines = state.lines,
            })
            state = get_initial_state()
        elseif
            not state.start_line
            and not line:find("dev/null", 1, true) -- can't parse filename if it's dev/null
            and (vim.startswith(line, "---") or vim.startswith(line, "+++")) -- filenames start with these chars
        then
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
        local filename = populate_file(state.filename, commit)
        table.insert(qf_locations, {
            filename = filename,
            lines = state.lines,
        })
    end
    return qf_locations
end

---@param commit? string
local function get_qf_locations(commit)
    local cmd = commit and ("diff " .. commit) or "diff"
    local command_builder = Command.base_command(cmd)
    local diff_output = require("trunks._core.run_cmd").run_cmd(command_builder)

    return M._parse_diff_output(diff_output, commit)
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

---@param commit? string
function M.render(commit)
    local qf_locations = get_qf_locations(commit)
    local flattened_qf_locations = {}

    for _, location in ipairs(qf_locations) do
        for _, line in ipairs(location.lines) do
            table.insert(flattened_qf_locations, {
                filename = location.filename,
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
