---@class trunks.Command
---@field base string | nil
---@field _prefix string[]
---@field _args string[]
---@field _prefix_args string[]
---@field _postfix_args string[]
---@field _env_vars string[]
---@field _pager string?
---@field add_args fun(self: trunks.Command, args: string): trunks.Command
---@field add_prefix_args fun(self: trunks.Command, args: string): trunks.Command
---@field add_postfix_args fun(self: trunks.Command, args: string): trunks.Command
---@field add_env_var fun(self: trunks.Command, args: string): trunks.Command
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

---@param cmd? string
---@return string?
local function get_pager(cmd)
    if not cmd then
        return nil
    end

    local base_cmd = require("trunks._core.texter").get_base_cmd(cmd)
    if base_cmd then
        local cmd_pager = vim.tbl_get(require("trunks._core.configuration"), "DATA", base_cmd, "pager")
        if cmd_pager then
            return cmd_pager
        end
    end

    local default_pager = vim.tbl_get(require("trunks._core.configuration"), "DATA", "pager")
    return default_pager
end

Command.__index = Command

---@param cmd? string
---@param filename? string
---@return trunks.Command
function Command.base_command(cmd, filename)
    local self = setmetatable({}, Command)
    self.base = cmd
    self._prefix = { "git" }
    self._args = {}
    self._prefix_args = { "--no-pager" }
    self._postfix_args = {}
    self._env_vars = {}
    self._pager = get_pager(cmd)

    -- If the current buffer is outside cwd when this Command is instatiated, add a -C flag
    local git_c_flag = require("trunks._core.parse_command").get_git_c_flag(filename)
    if git_c_flag then
        table.insert(self._prefix, git_c_flag)
    end

    return self
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

function Command:add_env_var(args)
    table.insert(self._env_vars, args)
    return self
end

function Command:build()
    local unpack = unpack or table.unpack
    local cmd_parts
    if #self._env_vars > 0 then
        cmd_parts = { unpack(self._env_vars), unpack(self._prefix) }
    else
        cmd_parts = { unpack(self._prefix) }
    end
    table_insert_if_exists(cmd_parts, self._prefix_args)
    if self.base then
        table.insert(cmd_parts, self.base)
    end
    table_insert_if_exists(cmd_parts, self._args)
    table_insert_if_exists(cmd_parts, self._postfix_args)
    local built_cmd = table.concat(cmd_parts, " ")

    if self._pager then
        local adapter = require("trunks._core.pagers")[self._pager]
        if adapter then
            built_cmd = adapter(built_cmd)
        end
    end
    return built_cmd
end

return Command
