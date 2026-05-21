local M = {}

---@return string
local function get_num_commits_to_pull_and_push()
    local system = require("trunks._core.run_cmd").system
    local result = system("git rev-list --left-right --count @{u}...HEAD")
    if result.code ~= 0 or not result.output[1] then
        return ""
    end
    -- `--left-right ... @{u}...HEAD`: left count = behind (pull), right count = ahead (push)
    local pull, push = result.output[1]:match("(%d+)%s+(%d+)")
    if not pull then
        return ""
    end

    local out = ""
    if pull ~= "0" then
        out = out .. "↓" .. pull
    end
    if push ~= "0" then
        if out ~= "" then
            out = out .. " "
        end
        out = out .. "↑" .. push
    end
    return out
end

---@param bufnr integer
local function render_num_commits(bufnr)
    if not vim.api.nvim_buf_is_valid(bufnr) then
        return
    end

    local existing_line = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1]
    if not existing_line then
        return
    end

    local stripped = existing_line:gsub(" ↓%d+", ""):gsub(" ↑%d+", "")
    local commits_str = get_num_commits_to_pull_and_push()
    local new_line = stripped
    if #commits_str > 0 then
        new_line = stripped .. " " .. commits_str
    end
    require("trunks._ui.utils.buffer_text").set(bufnr, { new_line }, 0, 1)
end

--- Runs `git fetch` in the background and then rewrites the ahead/behind
--- suffix on the Head line. Network-bound, so call this *after* the initial
--- status render.
---@param bufnr integer
M.set_num_commits_to_pull_and_push = vim.schedule_wrap(function(bufnr)
    if vim.api.nvim_buf_is_valid(bufnr) then
        vim.b[bufnr].trunks_fetch_running = true
    end
    vim.fn.jobstart("git fetch", {
        on_exit = function()
            if vim.api.nvim_buf_is_valid(bufnr) then
                vim.b[bufnr].trunks_fetch_running = false
            end
            render_num_commits(bufnr)
        end,
    })
end)

return M
