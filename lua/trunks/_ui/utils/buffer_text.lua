local M = {}

---@param bufnr integer
---@param lines string[]
---@param start integer | nil
---@param end_ integer | nil
function M.set(bufnr, lines, start, end_)
    if not vim.api.nvim_buf_is_valid(bufnr) then
        return
    end

    start = start or 0
    end_ = end_ or -1
    local original_modifiable = vim.bo[bufnr].modifiable
    vim.bo[bufnr].modifiable = true
    vim.api.nvim_buf_set_lines(bufnr, start, end_, false, lines)
    vim.bo[bufnr].modifiable = original_modifiable
end

return M
