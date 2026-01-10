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

---@param lines string[]
---@return trunks.DiffQfHunk[]
function M._parse_diff_output(lines)
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
        table.insert(qf_locations, {
            filename = state.filename,
            lines = state.lines,
        })
    end
    return qf_locations
end

---@param commit? string
local function get_qf_locations(commit)
    local cmd = commit and ("diff " .. commit) or "diff"
    local command_builder = Command.base_command(cmd)
    local diff_output = require("trunks._core.run_cmd").run_cmd(command_builder, { no_pager = true })

    return M._parse_diff_output(diff_output)
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
    vim.cmd.tabnew()
    local diff_qf_tab_id = vim.api.nvim_get_current_tabpage()

    local qf_locations = get_qf_locations(commit)
    local flattened_qf_locations = {}
    local found_filenames = {}
    local filenames = {}

    for _, location in ipairs(qf_locations) do
        for _, line in ipairs(location.lines) do
            table.insert(flattened_qf_locations, {
                filename = location.filename,
                lnum = line.line_num,
                text = line.text,
                user_data = { filename = location.filename },
            })
            if not found_filenames[location.filename] then
                table.insert(filenames, location.filename)
                found_filenames[location.filename] = true
            end
        end
    end

    vim.api.nvim_create_autocmd({ "BufWinEnter" }, {
        group = vim.api.nvim_create_augroup("TrunksDiffQf", { clear = true }),
        pattern = filenames,
        callback = function(args)
            if vim.api.nvim_get_current_tabpage() ~= diff_qf_tab_id then
                return
            end
            local bufnr = args.buf
            local current_win = vim.api.nvim_get_current_win()
            local split_win
            local split_bufnr = vim.b[bufnr].split_bufnr
            if split_bufnr then
                split_win = vim.api.nvim_open_win(split_bufnr, false, { split = "right" })
            else
                if commit then
                    vim.cmd("Trunks vdiff " .. commit)
                else
                    vim.cmd("Trunks vdiff")
                end
                vim.b[bufnr].split_bufnr = vim.api.nvim_get_current_buf()
                split_win = vim.api.nvim_get_current_win()
                vim.cmd("wincmd p")
            end

            -- Close any wins aside from splits and things like qflist
            for _, win in ipairs(vim.api.nvim_tabpage_list_wins(diff_qf_tab_id)) do
                local is_diff_win = win == current_win or win == split_win
                local winnr = vim.api.nvim_win_get_number(win)
                local win_type = vim.fn.win_gettype(winnr)
                local is_special_win = win_type ~= nil and win_type ~= "" and win_type ~= "unknown"
                if (not is_diff_win) and not is_special_win then
                    vim.fn.win_execute(win, "diffoff", true)
                    vim.api.nvim_win_close(win, false)
                elseif is_diff_win then
                    -- When vdiff buffers are hidden, they turn off diff mode, so we need to re enable it
                    vim.fn.win_execute(win, "diffthis", true)
                end
            end
        end,
        desc = "Trunks: open/close diff-qf splits",
    })

    vim.api.nvim_create_autocmd("TabClosed", {
        callback = function(args)
            local tab_num = tonumber(args.file)
            if tab_num == diff_qf_tab_id then
                vim.api.nvim_clear_autocmds({ group = "TrunksDiffQf" })
            end
        end,
    })

    vim.fn.setqflist({}, "r", {
        title = "Trunks diff-qf",
        items = flattened_qf_locations,
        quickfixtextfunc = format_qf,
    })
    vim.cmd.copen()
    highlight_qf_buffer(vim.api.nvim_get_current_buf())
    require("trunks._core.autocmds").execute_user_autocmds({ ui_type = "quickfix", ui_name = "diff_qf" })
end

return M
