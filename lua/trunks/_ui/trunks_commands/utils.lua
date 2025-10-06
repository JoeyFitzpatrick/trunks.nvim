local M = {}

M.MIN_HASH_LENGTH = 7

---@param hash string | nil
---@return boolean
function M.validate_hash(hash)
    return type(hash) == "string" and #hash >= M.MIN_HASH_LENGTH
end

---@param ok_text string | nil
---@param error_text string[] | string
---@param error_code integer | nil
function M.handle_output(ok_text, error_text, error_code)
    local is_ok = error_code == nil or error_code == 0
    if is_ok then
        if ok_text then
            vim.notify(ok_text, vim.log.levels.INFO)
        end
        return
    end
    if type(error_text) == "table" then
        error_text = table.concat(error_text, "\n")
    end
    vim.notify(error_text, vim.log.levels.ERROR)
end

return M
