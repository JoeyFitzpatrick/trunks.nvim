local M = {}

M.MIN_HASH_LENGTH = 7

---@param hash string | nil
---@return boolean
function M.validate_hash(hash)
    return type(hash) == "string" and #hash >= M.MIN_HASH_LENGTH
end

return M
