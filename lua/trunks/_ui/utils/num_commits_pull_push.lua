---@class trunks.SetNumCommitsParams
---@field branch string

local M = {}

---@param branch string
---@return string
local function get_num_commits_to_pull_and_push(branch)
    if branch:match("%s-remotes/") then
        return ""
    end
    local system = require("trunks._core.run_cmd").system
    local pull_lines_result = system(string.format("git rev-list --count %s..origin/%s", branch, branch))
    local push_lines_result = system(string.format("git rev-list --count origin/%s..%s", branch, branch))
    if pull_lines_result.code ~= 0 or push_lines_result.code ~= 0 then
        return ""
    end
    local pull, push = pull_lines_result.output[1], push_lines_result.output[1]
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

    local commits_str = get_num_commits_to_pull_and_push(branch)
    if #commits_str > 0 then
        local existing_line = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1]
        if not existing_line then
            return
        end
        local existing_line_without_commits_str = existing_line:gsub(" ↓%d+", ""):gsub(" ↑%d+", "")
        local new_line = { existing_line_without_commits_str .. " " .. commits_str }
        require("trunks._ui.utils.buffer_text").set(bufnr, new_line, 0, 1)
    end
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
    vim.fn.jobstart("git fetch", {
        on_exit = function()
            if vim.api.nvim_buf_is_valid(bufnr) then
                vim.b[bufnr].trunks_fetch_running = false
            end
            render_num_commits(bufnr, opts)
        end,
    })
end)

return M
