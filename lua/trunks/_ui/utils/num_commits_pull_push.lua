---@class trunks.SetNumCommitsParams
---@field line_num integer
---@field branch string

local M = {}

---@param branch string
---@return string
local function get_num_commits_to_pull_and_push(branch)
    if branch:match("%s-remotes/") then
        return ""
    end
    local run_cmd = require("trunks._core.run_cmd").run_cmd
    local pull_lines, pull_error_code = run_cmd(string.format("rev-list --count %s..origin/%s", branch, branch))
    local push_lines, push_error_code = run_cmd(string.format("rev-list --count origin/%s..%s", branch, branch))
    if pull_error_code ~= 0 or push_error_code ~= 0 then
        return ""
    end
    local pull, push = pull_lines[1], push_lines[1]
    local pull_and_push = ""
    if pull ~= "0" then
        pull_and_push = pull_and_push .. "↓" .. pull
    end
    if push ~= "0" then
        if pull_and_push ~= "" then
            pull_and_push = pull_and_push .. " "
        end
        pull_and_push = pull_and_push .. "↑" .. push
    end
    return pull_and_push
end

---@param bufnr integer
---@param opts trunks.SetNumCommitsParams
local function render_num_commits(bufnr, opts)
    if not vim.api.nvim_buf_is_valid(bufnr) then
        return
    end

    local branch = opts.branch
    local line_num = opts.line_num

    vim.bo[bufnr].modifiable = true
    vim.api.nvim_buf_set_text(bufnr, line_num, -1, line_num, -1, { " " .. get_num_commits_to_pull_and_push(branch) })
    vim.bo[bufnr].modifiable = false
end

--- This function is `vim.schedule_wrap`ped, so that it doesn't
--- block the main thread. Otherwise it causes sluggishness.
---@param bufnr integer
---@param opts trunks.SetNumCommitsParams
M.set_num_commits_to_pull_and_push = vim.schedule_wrap(function(bufnr, opts)
    if vim.api.nvim_buf_is_valid(bufnr) then
        vim.b[bufnr].trunks_fetch_running = true
    end
    render_num_commits(bufnr, opts)
    local received_output = false
    vim.fn.jobstart("git fetch", {
        on_stdout = function(_, data, _)
            for _, line in ipairs(data) do
                if line and line ~= "" then
                    received_output = true
                    return
                end
            end
        end,
        on_stderr = function(_, data, _)
            for _, line in ipairs(data) do
                if line and line ~= "" then
                    received_output = true
                    return
                end
            end
        end,
        on_exit = function(_, code, _)
            if vim.api.nvim_buf_is_valid(bufnr) then
                vim.b[bufnr].trunks_fetch_running = false
            end
            if code ~= 0 or not received_output then
                return
            end
            render_num_commits(bufnr, opts)
        end,
    })
end)

return M
