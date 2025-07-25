local M = {}

--- If no command is passed in, return the current branch.
--- Otherwise, parse the branch from the command passed in.
--- Includes handling for detached HEAD and errors.
---@param command_builder? trunks.Command
---@return string
function M.get_current_head(command_builder)
    if command_builder and command_builder.base then
        local branch = require("trunks._core.texter").find_non_dash_arg(command_builder.base:sub(5))
        if branch then
            return "Branch: " .. branch
        end
    end
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

---@param bufnr integer
---@param line string
---@param line_num integer
function M.highlight_head_line(bufnr, line, line_num)
    if line:match("^HEAD:") or line:match("^Branch:") then
        local head_start, head_end = line:find("%s%S+")
        require("trunks._ui.highlight").highlight_line(bufnr, "Identifier", line_num, head_start, head_end)
    end
end

return M
