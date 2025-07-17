local M = {}

---@param message string
---@param opts? table
---@return boolean
function M.confirm_choice(message, opts)
    opts = opts or {}
    opts.values = opts.values or { "&Yes", "&No" }
    opts.default = opts.default or 2

    return vim.fn.confirm(message, table.concat(opts.values, "\n"), opts.default) == 1
end

return M
