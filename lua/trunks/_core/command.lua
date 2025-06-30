---@class trunks.Command
---@field base string | nil
---@field _prefix string[]
---@field _args string[]
---@field _prefix_args string[]
---@field _postfix_args string[]
---@field base_command fun(cmd: string | nil): trunks.Command
---@field add_args fun(self: trunks.Command, args: string): trunks.Command
---@field add_prefix_args fun(self: trunks.Command, args: string): trunks.Command
---@field add_postfix_args fun(self: trunks.Command, args: string): trunks.Command
---@field build fun(self: trunks.Command): string
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

function Command.base_command(cmd)
    local self = setmetatable({}, Command)
    self.base = cmd
    self._prefix = { "git" }
    self._args = {}
    self._prefix_args = {}
    self._postfix_args = {}

    -- If the current buffer is outside cwd when this Command is instatiated, add a -C flag
    local git_c_flag = require("trunks._core.parse_command").get_git_c_flag()
    if git_c_flag then
        table.insert(self._prefix, git_c_flag)
    end

    return self
end

--- Sometimes we need to pass around a -C flag that is generated, so here's a way
--- to get it from a Command instance.
---@return string | nil
function Command:get_c_flag()
    return self._prefix[2]
end

function Command:add_prefix_args(args)
    table.insert(self._prefix_args, args)
    return self
end

function Command:add_args(args)
    table.insert(self._args, args)
    return self
end

function Command:add_postfix_args(args)
    table.insert(self._postfix_args, args)
    return self
end

function Command:build()
    local cmd_parts = self._prefix
    table_insert_if_exists(cmd_parts, self._prefix_args)
    if self.base then
        table.insert(cmd_parts, self.base)
    end
    table_insert_if_exists(cmd_parts, self._args)
    table_insert_if_exists(cmd_parts, self._postfix_args)
    return table.concat(cmd_parts, " ")
end

return Command
