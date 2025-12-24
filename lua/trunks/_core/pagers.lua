local M = {}

---@param cmd string
---@return string
function M.delta(cmd)
    return cmd .. " | delta --paging=never"
end

return M
