local M = {}

---@return string
local function get_current_head_for_term()
    local ERROR_MSG = "HEAD: Unable to find current HEAD"
    local Command = require("trunks._core.command")
    local current_head, status_code =
        require("trunks._core.run_cmd").run_cmd(Command.base_command("symbolic-ref --short HEAD"))

    local detached_head_message = "fatal: ref HEAD is not a symbolic ref"
    if current_head[1] == detached_head_message then
        local current_head_hash, hash_status_code =
            require("trunks._core.run_cmd").run_cmd(Command.base_command("rev-parse --short HEAD"))
        if hash_status_code ~= 0 then
            return ERROR_MSG
        end
        return string.format("HEAD: %s (detached head)", current_head_hash[1])
    end

    if status_code ~= 0 or not current_head[1] then
        return ERROR_MSG
    end

    return "HEAD: " .. current_head[1]
end

--- Highlights returned string with ANSI codes. Includes handling for detached HEAD and errors.
---@return string
function M.get_current_head()
    local current_head = get_current_head_for_term()
    -- Highlight "HEAD" in purple using ANSI escape codes
    local purple = "\27[35m"
    local blue = "\27[34m"
    local reset = "\27[0m"
    return current_head:gsub("HEAD:", purple .. "HEAD:" .. blue) .. reset
end

return M
