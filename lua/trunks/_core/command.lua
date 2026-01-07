---@class trunks.Command
---@field base string | nil
---@field _prefix string[]
---@field _args string[]
---@field _prefix_args string[]
---@field _postfix_args string[]
---@field _env_vars string[]
---@field _pager trunks.Pager?
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

local PAGER_COMMANDS = {
    diff = true,
    grep = true,
    show = true,
    stash = { "-p" },
    log = { "-p" },
}

local PAGERS = require("trunks._constants.pagers").PAGERS

---@param cmd? string
---@return string?
local function get_pager(cmd)
    if not cmd then
        return nil
    end

    local base_cmd = require("trunks._core.texter").get_base_cmd(cmd)
    if not base_cmd then
        return nil
    end

    local pager_opts = PAGER_COMMANDS[base_cmd]
    if not pager_opts then
        return nil
    end

    -- Some commands should only use a pager if they have a specific flag
    if type(pager_opts) == "table" and not require("trunks._core.texter").has_options(cmd, pager_opts) then
        return nil
    end

    local cmd_pager = vim.tbl_get(require("trunks._core.configuration"), "DATA", base_cmd, "pager")
    if cmd_pager and PAGERS[cmd_pager] then
        return PAGERS[cmd_pager]
    end

    local default_pager = vim.tbl_get(require("trunks._core.configuration"), "DATA", "pager")
    if PAGERS[default_pager] then
        return PAGERS[default_pager]
    end
    return nil
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

---@class trunks.CommandBuildOpts
---@field skip_prefix? boolean

---@param opts? trunks.CommandBuildOpts
---@return string
function Command:build(opts)
    opts = opts or {}
    local pager = self._pager
    if pager then
        if pager.type == "postfix" and not vim.tbl_contains(self._postfix_args, pager.command) then
            self:add_postfix_args("| " .. pager.command)
        elseif pager.type == "prefix" and not vim.tbl_contains(self._prefix_args, pager.command) then
            self:add_prefix_args(pager.command)
        end
    end

    local unpack = unpack or table.unpack
    local cmd_parts
    if #self._env_vars > 0 then
        cmd_parts = { unpack(self._env_vars), unpack(self._prefix) }
    else
        cmd_parts = { unpack(self._prefix) }
    end
    if not opts.skip_prefix then
        table_insert_if_exists(cmd_parts, self._prefix_args)
    end
    if self.base then
        table.insert(cmd_parts, self.base)
    end
    table_insert_if_exists(cmd_parts, self._args)
    table_insert_if_exists(cmd_parts, self._postfix_args)
    local built_cmd = table.concat(cmd_parts, " ")

    return built_cmd
end

return Command
