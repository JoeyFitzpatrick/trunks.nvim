local M = {}

--- A helper to accomplish two things:
--- 1. Skip setting keymap if lhs is nil
--- 2. Assert that opts are passed in so we don't forget to pass them in
---@param mode string | string[]
---@param lhs? string
---@param rhs string | function
---@param opts vim.keymap.set.Opts
function M.safe_set_keymap(mode, lhs, rhs, opts)
    if not lhs or lhs == "" then
        return
    end
    vim.keymap.set(mode, lhs, rhs, opts)
end

function M.set_q_keymap(bufnr)
    vim.keymap.set("n", "q", function()
        require("trunks._core.register").deregister_buffer(bufnr, {})
    end, { buffer = bufnr })
end

--- Returns a function that calls fn(line_data) only when line data is available.
--- Use this to eliminate boilerplate in keymap handlers and auto_display callbacks.
---@param bufnr integer
---@param get_line_fn fun(bufnr: integer, ...): any
---@param fn fun(line_data: any)
---@return function
function M.with_line(bufnr, get_line_fn, fn)
    return function()
        local ok, line_data = pcall(get_line_fn, bufnr)
        if not ok or not line_data then
            return
        end
        return fn(line_data)
    end
end

return M
