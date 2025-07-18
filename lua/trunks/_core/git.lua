local M = {}

--- Returns true for a git status that represents a staged file, and false otherwise.
---@param status string
---@return boolean
M.is_staged = function(status)
    return vim.tbl_contains(require("trunks._constants.git_status").STAGED_STATUSES, status)
end

--- Returns true for a git status that represents a modified file, and false otherwise.
---@param status string
---@return boolean
M.is_modified = function(status)
    if not status then
        return false
    end
    -- A status that is partially staged, or modified, should always be two uppercase letters.
    return status:match("^%u%u$") ~= nil
end

--- Returns true for a git status that represents a deleted file, and false otherwise.
---@param status string
---@return boolean
M.is_deleted = function(status)
    return vim.tbl_contains(require("trunks._constants.git_status").DELETED_STATUSES, status)
end

--- Returns true for a git status that represents a deleted file, and false otherwise.
---@param status string
---@return boolean
M.is_renamed = function(status)
    return vim.tbl_contains(require("trunks._constants.git_status").RENAMED_STATUSES, status)
end

--- Returns true for a git status that represents an untracked file, and false otherwise.
---@param status string
---@return boolean
M.is_untracked = function(status)
    return status == "??"
end

M.is_anything_staged = function()
    local _, exit_code = require("trunks._core.run_cmd").run_cmd("git diff --cached --quiet")
    -- git diff --cached --quiet returns non-zero exit code if there are staged changes
    return exit_code ~= 0
end

return M
