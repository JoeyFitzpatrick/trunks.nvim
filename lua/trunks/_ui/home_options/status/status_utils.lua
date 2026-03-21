local M = {}

--- Given a list of files, return true if all files should be staged,
--- and false otherwise.
--- This returns true if any of the given files are not staged.
---@param files string[]
---@return boolean
function M.should_stage_files(files)
    for _, file in ipairs(files) do
        if file:match("^.%S") then
            return true
        end
    end
    return false
end

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
            table.insert(untracked, "? " .. filename)
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
    local diff_stat_cmd_output, diff_stat_cmd_exit_code = require("trunks._core.run_cmd").run_cmd(diff_stat_cmd)
    if diff_stat_cmd_exit_code == 0 and diff_stat_cmd_output[1] then
        return diff_stat_cmd_output[1]
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

return M
