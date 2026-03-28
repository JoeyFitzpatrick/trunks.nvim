local M = {}

local Command = require("trunks._core.command")

---@class trunks.StatusFiles
---@field staged string[]
---@field unstaged string[]
---@field untracked string[]
---@field unstaged_and_untracked string[]

---@param get_files_fn? fun(): string[]
---@return trunks.StatusFiles
function M.get_status_files(get_files_fn)
    get_files_fn = get_files_fn
        or function()
            local cmd = Command.base_command("status -s"):build()
            local files = require("trunks._core.run_cmd").run_cmd(cmd)
            return files
        end

    local files = get_files_fn()

    local staged = {}
    local unstaged = {}
    local untracked = {}

    for _, file in ipairs(files) do
        local filename = file:sub(4)
        if file:sub(1, 2) == "??" then
            if filename:sub(-1) == "/" then
                local ls_cmd = Command.base_command("ls-files --others --exclude-standard -- " .. filename):build()
                local dir_files = require("trunks._core.run_cmd").run_cmd(ls_cmd)
                for _, dir_file in ipairs(dir_files) do
                    if dir_file ~= "" then
                        table.insert(untracked, "? " .. dir_file)
                    end
                end
            else
                table.insert(untracked, "? " .. filename)
            end
        else
            local first_char = file:sub(1, 1)
            local second_char = file:sub(2, 2)
            if first_char ~= " " then
                table.insert(staged, first_char .. " " .. filename)
            end
            if second_char ~= " " then
                table.insert(unstaged, second_char .. " " .. filename)
            end
        end
    end

    local unstaged_and_untracked = {}
    for _, file in ipairs(unstaged) do
        table.insert(unstaged_and_untracked, file)
    end
    for _, file in ipairs(untracked) do
        table.insert(unstaged_and_untracked, file)
    end

    local result = {
        staged = staged,
        unstaged = unstaged,
        untracked = untracked,
        unstaged_and_untracked = unstaged_and_untracked,
    }

    for _, tbl in pairs(result) do
        table.sort(tbl, function(left, right)
            return left:sub(3) < right:sub(3)
        end)
    end

    return result
end

---@param diff_stat_text? string
function M.get_diff_stat(diff_stat_text)
    if diff_stat_text then
        return diff_stat_text
    end
    local diff_stat_cmd = Command.base_command("diff --staged --shortstat"):build({ no_pager = true })
    local diff_cmd_output, exit_code = require("trunks._core.run_cmd").run_cmd(diff_stat_cmd)
    local output = diff_cmd_output[1]
    if exit_code == 0 and output then
        return vim.trim(output)
    else
        return "No staged changes"
    end
end

---@param remote_branch_text? string
function M.get_remote_branch(remote_branch_text)
    if remote_branch_text then
        return remote_branch_text
    end
    local run_cmd = require("trunks._core.run_cmd").run_cmd

    local upstream_cmd = Command.base_command("rev-parse --abbrev-ref --symbolic-full-name @{u}"):build()
    local upstream_output, upstream_exit_code = run_cmd(upstream_cmd)

    if upstream_exit_code ~= 0 or not upstream_output[1] then
        local branch_cmd = Command.base_command("symbolic-ref --short HEAD"):build()
        local branch_output, branch_exit_code = run_cmd(branch_cmd)
        local branch = (branch_exit_code == 0 and branch_output[1]) or "HEAD"
        return "Push: " .. branch
    end

    local upstream = upstream_output[1]

    local rebase_cmd = Command.base_command("config pull.rebase"):build()
    local rebase_output, rebase_exit_code = run_cmd(rebase_cmd)

    local prefix
    if rebase_exit_code == 0 and rebase_output[1] and rebase_output[1] ~= "false" then
        prefix = "Rebase: "
    else
        prefix = "Merge: "
    end

    return prefix .. upstream
end

---@class trunks.SetStatusFilesVariableParams
---@field files trunks.StatusFiles
---@field unstaged_untracked_index? integer
---@field staged_index? integer

---@class trunks.StatusFilesBufferVariableEntry
---@field status string
---@field staged boolean
---@field expanded boolean

---@class trunks.StatusFilesBufferVariable
---@field staged table<string, trunks.StatusFilesBufferVariableEntry>
---@field unstaged table<string, trunks.StatusFilesBufferVariableEntry>

---@param bufnr integer
---@param opts trunks.SetStatusFilesVariableParams
---@return trunks.StatusFilesBufferVariable
function M.set_status_files_variable(bufnr, opts)
    local trunks_status_files = { staged = {}, unstaged = {} }

    if opts.unstaged_untracked_index then
        for _, file in ipairs(opts.files.unstaged_and_untracked) do
            local filename = file:sub(3)
            trunks_status_files.unstaged[filename] = { status = file:sub(1, 1), staged = false, expanded = false }
        end
    end

    if opts.staged_index then
        for _, file in ipairs(opts.files.staged) do
            local filename = file:sub(3)
            trunks_status_files.staged[filename] = { status = file:sub(1, 1), staged = true, expanded = false }
        end
    end
    vim.b[bufnr].trunks_status_files = trunks_status_files
    return trunks_status_files
end

---@param line_data trunks.StatusLineData
---@return string
function M.get_diff_cmd(line_data)
    local status = line_data.status
    local safe_filename = line_data.safe_filename
    local is_staged = line_data.staged

    local is_untracked = status == "?"
    if is_untracked then
        return "diff --no-index /dev/null -- " .. safe_filename
    end

    if is_staged then
        return "diff --staged -- " .. safe_filename
    end

    local is_modified = status == "M"
    if is_modified then
        return "diff -- " .. safe_filename
    end

    return "diff -- " .. safe_filename
end

---@param bufnr integer
---@param line_num integer
---@param line_data trunks.StatusLineData
---@param run_cmd_fn? fun(cmd: string[]): string[], integer
function M.toggle_inline_diff(bufnr, line_num, line_data, run_cmd_fn)
    run_cmd_fn = run_cmd_fn or require("trunks._core.run_cmd").run_cmd
    local status_files = vim.b[bufnr].trunks_status_files
    local file
    if line_data.staged then
        file = status_files.staged[line_data.filename]
    else
        file = status_files.unstaged[line_data.filename]
    end

    if not file.expanded then
        local cmd = Command.base_command(M.get_diff_cmd(line_data):gsub("^diff", "diff --no-color"))
            :build({ no_pager = true })
        local diff_output, exit_code = run_cmd_fn(cmd)
        if exit_code == 0 or (exit_code == 1 and line_data.status == "?") then
            local start = 1
            for i, line in ipairs(diff_output) do
                if line:match("^@@") then
                    start = i
                    break
                end
            end
            local diff = vim.list_slice(diff_output, start)
            require("trunks._ui.utils.buffer_text").set(bufnr, diff, line_num, line_num)
            file.expanded = true
            vim.b[bufnr].trunks_status_files = status_files
        end
    else
        local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
        local diff_line_pattern = "^[%+%-@ ]"

        -- Walk back until a non-diff line is found
        local diff_start = nil
        while line_num > 0 and not diff_start do
            local line = lines[line_num]
            if not line:match(diff_line_pattern) then
                diff_start = line_num
                break
            end
            line_num = line_num - 1
        end

        -- Walk forward until non-diff line is found

        local diff_end = nil
        line_num = line_num + 1
        while line_num <= #lines and not diff_end do
            local line = lines[line_num]
            if not line:match(diff_line_pattern) then
                diff_end = line_num
                break
            end
            line_num = line_num + 1
        end
        if not diff_end then
            diff_end = line_num
        end

        require("trunks._ui.utils.buffer_text").set(bufnr, {}, diff_start, diff_end - 1)
        file.expanded = false
        vim.b[bufnr].trunks_status_files = status_files
    end
end

return M
