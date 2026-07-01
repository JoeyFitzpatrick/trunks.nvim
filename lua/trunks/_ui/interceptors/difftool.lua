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

---@param cmd string
---@return boolean
function M._is_name_only(cmd)
    -- `--name-only`/`--name-status` make git print a file list rather than hunks.
    return cmd:match("%-%-name%-only") ~= nil or cmd:match("%-%-name%-status") ~= nil
end

---@param lines string[]
---@return trunks.DiffQfHunk[]
function M._parse_name_only_output(lines)
    local qf_locations = {}
    for _, line in ipairs(lines) do
        if line ~= "" then
            -- --name-status prefixes a status (and, for renames, the old path) with tabs.
            local filename = line:match("([^\t]+)$")
            table.insert(qf_locations, {
                filename = filename,
                lines = { { line_num = 1, text = "" } },
            })
        end
    end
    return qf_locations
end

---@param command_builder trunks.Command
local function get_qf_locations(command_builder)
    local built = command_builder:build()
    local cmd = built:gsub("difftool", "diff", 1)
    local diff_output = require("trunks._core.run_cmd").run_cmd(cmd, { no_pager = true })

    if M._is_name_only(built) then
        return M._parse_name_only_output(diff_output)
    end
    return M._parse_diff_output(diff_output)
end

---Parse commit range from difftool arguments using git to resolve revisions
---@param cmd string The full command string
---@return string|nil left_commit The left side of the diff (nil for working tree)
---@return string|nil right_commit The right side of the diff (nil for working tree)
function M._parse_diff_revisions(cmd)
    local run_cmd = require("trunks._core.run_cmd").run_cmd

    local args = cmd:match("difftool%s+(.+)")
    if not args or args == "" then
        return "HEAD", nil
    end

    -- Trim whitespace
    args = args:match("^%s*(.-)%s*$")

    -- Drop option flags (e.g. --name-only) so only revisions remain.
    local rev_parts = {}
    for _, part in ipairs(vim.split(args, "%s+")) do
        if part ~= "" and not vim.startswith(part, "-") then
            table.insert(rev_parts, part)
        end
    end
    args = table.concat(rev_parts, " ")
    if args == "" then
        return "HEAD", nil
    end

    if args:match("%.%.%.") then
        -- Three-dot range: A...B means merge-base(A,B)..B
        local left, right = args:match("^(.-)%.%.%.(.+)$")
        if left and right then
            local merge_base_output = run_cmd("git merge-base " .. left .. " " .. right)
            if merge_base_output and #merge_base_output > 0 then
                local merge_base = merge_base_output[1]:match("^%s*(.-)%s*$")

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
        -- Split on whitespace to check for multiple commits
        local tokens = vim.split(args, "%s+")
        tokens = vim.tbl_filter(function(t)
            return t ~= ""
        end, tokens)

        if #tokens == 0 then
            return "HEAD", nil
        elseif #tokens == 1 then
            -- Single commit: diff working tree against commit
            local commit = tokens[1]
            return nil, commit
        elseif #tokens >= 2 then
            -- Two commits: diff against each other
            return tokens[1], tokens[2]
        end
    end

    return "HEAD", nil
end

---Set up the tab and autocmds that open a vdiff split for each quickfix entry.
---@param diff_qf_tab_id integer
---@param filenames string[]
---@param left_commit string|nil
---@param right_commit string|nil
local function setup_diff_splits(diff_qf_tab_id, filenames, left_commit, right_commit)
    local virtual_buffers = require("trunks._core.virtual_buffers")

    vim.api.nvim_create_autocmd({ "BufWinEnter" }, {
        group = vim.api.nvim_create_augroup("TrunksDiffQf", { clear = true }),
        pattern = filenames,
        callback = function(args)
            if vim.api.nvim_get_current_tabpage() ~= diff_qf_tab_id then
                return
            end
            local bufnr = args.buf
            local bufname = vim.api.nvim_buf_get_name(bufnr)
            local current_win = vim.api.nvim_get_current_win()

            -- Extract the real filepath for vdiff command
            local filepath
            if virtual_buffers.is_virtual_uri(bufname) then
                local parsed_uri = virtual_buffers.parse_file_uri(bufname)
                filepath = parsed_uri.filepath
            else
                filepath = bufname
            end

            if right_commit and not left_commit then
                -- Diff commit against working tree
                -- Current buffer is working tree, open commit in split
                vim.cmd("Trunks vdiff " .. right_commit)
            elseif right_commit then
                -- Diff between two specific commits
                -- We're already viewing right_commit, so open left_commit in the split
                require("trunks._core.open_file").open_file_in_split(filepath, left_commit, "right", {})
            else
                -- No commits specified, diff against working tree
                vim.cmd("Trunks vdiff")
            end

            local split_win = vim.api.nvim_get_current_win()
            vim.cmd("wincmd p")

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
                    vim.api.nvim_exec_autocmds("BufReadCmd", { buffer = vim.fn.winbufnr(win) })
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
end

---@param command_builder trunks.Command
---@param input_args? vim.api.keyset.create_user_command.command_args
function M.render(command_builder, input_args)
    -- With a bang (`:G! difftool`), skip the diff splits/tab and just populate the
    -- quickfix list, then jump to the first entry.
    local bang = input_args ~= nil and input_args.bang or false
    local cmd = command_builder.base or ""
    local left_commit, right_commit = M._parse_diff_revisions(cmd)

    local qf_locations = get_qf_locations(command_builder)
    if #qf_locations == 0 then
        vim.notify("trunks: no diffs found for difftool", vim.log.levels.ERROR)
        return
    end

    local virtual_buffers = require("trunks._core.virtual_buffers")
    local git_root = require("trunks._core.parse_command")._find_git_root()
    local flattened_qf_locations = {}
    local found_filenames = {}
    local filenames = {}

    for _, location in ipairs(qf_locations) do
        for _, line in ipairs(location.lines) do
            local qf_filename
            if left_commit and right_commit then
                qf_filename = virtual_buffers.create_uri(git_root, right_commit, location.filename)
            else
                qf_filename = location.filename
            end

            table.insert(flattened_qf_locations, {
                filename = qf_filename,
                lnum = line.line_num,
                text = line.text,
                user_data = {
                    filename = location.filename,
                    left_commit = left_commit,
                    right_commit = right_commit,
                },
            })
            if not found_filenames[qf_filename] then
                table.insert(filenames, qf_filename)
                found_filenames[qf_filename] = true
            end
        end
    end

    if not bang then
        vim.cmd.tabnew()
        local diff_qf_tab_id = vim.api.nvim_get_current_tabpage()
        setup_diff_splits(diff_qf_tab_id, filenames, left_commit, right_commit)
    end

    vim.fn.setqflist({}, "r", {
        title = "Trunks diff-qf",
        items = flattened_qf_locations,
    })
    vim.cmd("copen | cfirst")
end

return M
