local M = {}

---@param bufnr integer
---@param lines string[]
---@param start integer | nil
---@param end_ integer | nil
function M.set(bufnr, lines, start, end_)
    start = start or 0
    end_ = end_ or -1
    vim.bo[bufnr].modifiable = true
    vim.api.nvim_buf_set_lines(bufnr, start, end_, false, lines)
    vim.bo[bufnr].modifiable = false
end

return M
