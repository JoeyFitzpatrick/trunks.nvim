local M = {}

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
            local Command = require("trunks._core.command")
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
                local Command = require("trunks._core.command")
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
    local Command = require("trunks._core.command")
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
    local Command = require("trunks._core.command")

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

---@param bufnr integer
---@param opts trunks.SetStatusFilesVariableParams
function M.set_status_files_variable(bufnr, opts)
    local trunks_status_files = {}

    if opts.unstaged_untracked_index then
        for i, file in ipairs(opts.files.unstaged_and_untracked) do
            trunks_status_files[i + opts.unstaged_untracked_index] =
                { filename = file:sub(3), status = file:sub(1, 1), staged = false }
        end
    end

    if opts.staged_index then
        for i, file in ipairs(opts.files.staged) do
            trunks_status_files[i + opts.staged_index] =
                { filename = file:sub(3), status = file:sub(1, 1), staged = true }
        end
    end
    vim.b[bufnr].trunks_status_files = trunks_status_files
end

return M
