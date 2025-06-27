local Command = {}

---@param tbl string[]
---@param strs (string | nil)[]
local function table_insert_if_exists(tbl, strs)
    for _, arg in ipairs(strs) do
        if arg and arg ~= "" then
            table.insert(tbl, arg)
        end
    end
end

Command.__index = Command

---@param cmd string | nil
function Command.base_command(cmd)
    local self = setmetatable({}, Command)
    self._base = cmd
    self._args = {}
    self._prefix_args = {}
    self._postfix_args = {}
    return self
end

---@param args string
function Command:add_prefix_args(args)
    table.insert(self._prefix_args, args)
    return self
end

---@param args string
function Command:add_args(args)
    table.insert(self._args, args)
    return self
end

---@param args string
function Command:add_postfix_args(args)
    table.insert(self._postfix_args, args)
    return self
end

---@return string
function Command:build()
    local cmd_parts = { "git" }
    local git_c_flag = require("trunks._core.parse_command").get_git_c_flag()
    if git_c_flag then
        table.insert(cmd_parts, git_c_flag)
    end
    table_insert_if_exists(cmd_parts, self._prefix_args)
    if self._base then
        table.insert(cmd_parts, self._base)
    end
    table_insert_if_exists(cmd_parts, self._args)
    table_insert_if_exists(cmd_parts, self._postfix_args)
    return table.concat(cmd_parts, " ")
end

return Command
