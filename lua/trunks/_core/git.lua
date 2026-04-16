local M = {}

M.is_anything_staged = function()
    local _, exit_code = require("trunks._core.run_cmd").run_cmd("diff --cached --quiet", { no_pager = true })
    -- git diff --cached --quiet returns non-zero exit code if there are staged changes
    return exit_code ~= 0
end

---@class trunks.CommitRange
---@field left string
---@field right string

---@param commit_range? string
---@return trunks.CommitRange?
M.parse_commit_range = function(commit_range)
    if not commit_range or commit_range == "" then
        return { left = require("trunks._constants.constants").WORKING_TREE, right = "HEAD" }
    end

    local is_single_commit = not commit_range:find("[%. ]")
    if is_single_commit then
        return { left = require("trunks._constants.constants").WORKING_TREE, right = commit_range }
    end

    local is_spaced_commit_range = commit_range:find("%s")
    if is_spaced_commit_range then
        local commits = vim.split(commit_range, " ", { trimempty = true })
        return { left = commits[1], right = commits[2] }
    end

    local commit_range_dots_index = commit_range:find("%.%.")
    if commit_range_dots_index then
        local commits = vim.split(commit_range, "..", { trimempty = true, plain = true })
        if commit_range_dots_index == 1 then
            return { left = "HEAD", right = commits[1] }
        else
            return { left = commits[1], right = commits[2] or "HEAD" }
        end
    end

    -- Unable to parse commits. Might not be bad to print an error message or something.
    return nil
end

return M
