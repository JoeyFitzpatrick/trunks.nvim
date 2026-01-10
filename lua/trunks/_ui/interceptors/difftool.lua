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

---@param command_builder trunks.Command
local function get_qf_locations(command_builder)
    local cmd = command_builder:build():gsub("difftool", "diff", 1)
    local diff_output = require("trunks._core.run_cmd").run_cmd(cmd, { no_pager = true })

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

---Parse commit range from difftool arguments using git to resolve revisions
---@param cmd string The full command string
---@return string|nil left_commit The left side of the diff (nil for working tree)
---@return string|nil right_commit The right side of the diff (nil for working tree)
local function parse_diff_revisions(cmd)
    local run_cmd = require("trunks._core.run_cmd").run_cmd

    -- Extract arguments after 'difftool'
    local args = cmd:match("difftool%s+(.+)")
    if not args or args == "" then
        -- No args: diff working tree against HEAD
        return "HEAD", nil
    end

    -- Trim whitespace
    args = args:match("^%s*(.-)%s*$")

    -- Check if this is a range (contains ..)
    if args:match("%.%.%.") then
        -- Three-dot range: A...B means merge-base(A,B)..B
        local left, right = args:match("^(.-)%.%.%.(.+)$")
        if left and right then
            -- Resolve the merge-base
            local merge_base_output = run_cmd("git merge-base " .. left .. " " .. right)
            if merge_base_output and #merge_base_output > 0 then
                local merge_base = merge_base_output[1]:match("^%s*(.-)%s*$")
                -- Resolve the right side
                local right_resolved_output = run_cmd("git rev-parse " .. right)
                local right_resolved = right_resolved_output and right_resolved_output[1]:match("^%s*(.-)%s*$")
                return merge_base, right_resolved
            end
        end
    elseif args:match("%.%.") then
        -- Two-dot range: A..B means diff between A and B
        local left, right = args:match("^(.-)%.%.(.+)$")
        if left and right then
            local left_resolved_output = run_cmd("git rev-parse " .. left)
            local right_resolved_output = run_cmd("git rev-parse " .. right)
            local left_resolved = left_resolved_output and left_resolved_output[1]:match("^%s*(.-)%s*$")
            local right_resolved = right_resolved_output and right_resolved_output[1]:match("^%s*(.-)%s*$")
            return left_resolved, right_resolved
        end
    else
        -- Could be: single commit, two commits, or complex ref
        -- Split on whitespace to check for multiple commits
        local tokens = vim.split(args, "%s+")
        tokens = vim.tbl_filter(function(t) return t ~= "" end, tokens)

        if #tokens == 0 then
            return "HEAD", nil
        elseif #tokens == 1 then
            -- Single commit: diff commit against its parent
            local commit = tokens[1]
            local resolved_output = run_cmd("git rev-parse " .. commit)
            local resolved = resolved_output and resolved_output[1]:match("^%s*(.-)%s*$")
            if resolved then
                -- Get parent commit
                local parent_output = run_cmd("git rev-parse " .. resolved .. "^")
                local parent = parent_output and parent_output[1]:match("^%s*(.-)%s*$")
                return parent, resolved
            end
        elseif #tokens >= 2 then
            -- Two commits: diff first against second
            local left_resolved_output = run_cmd("git rev-parse " .. tokens[1])
            local right_resolved_output = run_cmd("git rev-parse " .. tokens[2])
            local left_resolved = left_resolved_output and left_resolved_output[1]:match("^%s*(.-)%s*$")
            local right_resolved = right_resolved_output and right_resolved_output[1]:match("^%s*(.-)%s*$")
            return left_resolved, right_resolved
        end
    end

    -- Fallback
    return "HEAD", nil
end

---@param command_builder trunks.Command
function M.render(command_builder)
    local cmd = command_builder.base or ""
    local left_commit, right_commit = parse_diff_revisions(cmd)

    local qf_locations = get_qf_locations(command_builder)
    if #qf_locations == 0 then
        vim.notify("trunks: no diffs found for difftool", vim.log.levels.ERROR)
        return
    end

    vim.cmd.tabnew()
    local diff_qf_tab_id = vim.api.nvim_get_current_tabpage()

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
                if right_commit then
                    -- Diff between two specific commits
                    vim.cmd("Trunks vdiff " .. left_commit .. " " .. right_commit)
                elseif left_commit then
                    -- Diff commit against working tree
                    vim.cmd("Trunks vdiff " .. left_commit)
                else
                    -- No commits specified, diff against working tree
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
    require("trunks._core.autocmds").execute_user_autocmds({ ui_type = "quickfix", ui_name = "diff_qf" })
end

return M
