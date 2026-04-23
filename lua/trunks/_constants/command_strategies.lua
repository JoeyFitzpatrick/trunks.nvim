---@alias trunks.DisplayStrategy "above" | "below" | "right" | "left" | "full" | "print"
---@alias trunks.DisplayStrategyParser fun(cmd: string[]): trunks.DisplayStrategy
---@alias trunks.DisplayStrategyBoolParser fun(cmd: string[]): boolean

---@class trunks.Strategy
---@field display_strategy? trunks.DisplayStrategy | trunks.DisplayStrategyParser
---@field insert? boolean | trunks.DisplayStrategyBoolParser
---@field trigger_redraw? boolean | trunks.DisplayStrategyBoolParser
---@field enter? boolean
---@field pty? boolean | trunks.DisplayStrategyBoolParser
---@field tail? boolean
---

local M = {}

---@param cmd string[]
---@param options string[]
---@return boolean
function M._cmd_contains_options(cmd, options)
    for _, option in ipairs(options) do
        if
            vim.tbl_contains(cmd, function(cmd_part)
                return vim.startswith(cmd_part, option)
            end, { predicate = true })
        then
            return true
        end
    end
    return false
end

---@param cmd string[]
---@return boolean
local function is_full_screen_command(cmd)
    local full_screen_options = {
        "-i",
        "--interactive",
        "-p",
    }
    return M._cmd_contains_options(cmd, full_screen_options)
end

---@param cmd string
---@param custom_strategy? trunks.Strategy
---@return trunks.Strategy
function M.get_strategy(cmd, custom_strategy)
    local split_cmd = vim.split(cmd, " ", { trimempty = true })
    local base_cmd = split_cmd[2]
    if base_cmd and vim.startswith(base_cmd, "-") then
        base_cmd = split_cmd[3]
    end

    custom_strategy = custom_strategy or {}
    local default_strategy = vim.tbl_extend("force", M.default, custom_strategy)
    if not base_cmd then
        return default_strategy
    end

    local command_strategy = M[base_cmd]
    if not command_strategy then
        return default_strategy
    end

    if command_strategy.trigger_redraw == true and not command_strategy.display_strategy then
        command_strategy.display_strategy = M.STRATEGIES.PRINT
    end

    local merged_strategy = vim.tbl_extend("force", M.default, command_strategy, custom_strategy)
    local final_strategy = {}
    for key, value in pairs(merged_strategy) do
        if type(value) == "function" then
            final_strategy[key] = value(split_cmd)
        else
            final_strategy[key] = value
        end
    end
    return final_strategy
end

---@type table<string, trunks.DisplayStrategy>
M.STRATEGIES = {
    ABOVE = "above",
    BELOW = "below",
    RIGHT = "right",
    LEFT = "left",
    FULL = "full",
    PRINT = "print",
}

M.default = {
    display_strategy = M.STRATEGIES.BELOW,
    insert = false,
    trigger_redraw = false,
    pty = false,
}

---@type trunks.Strategy
M.add = {
    display_strategy = function(cmd)
        if is_full_screen_command(cmd) then
            return M.STRATEGIES.FULL
        end
        return M.STRATEGIES.PRINT
    end,
    insert = is_full_screen_command,
    trigger_redraw = true,
}

M.annotate = { insert = false }

local branch_write_command_args = {
    "-d",
    "-D",
    "--delete",
    "-m",
    "--move",
    "-M",
    "-c",
    "--copy",
}

---@type trunks.Strategy
M.branch = {
    pty = function(cmd)
        local branch_pty_options = {
            "--color",
            "--no-color",
            "-i",
            "--ignore-case",
            "--omit-empty",
            "--no-column",
            "-r",
            "--remotes",
            "-a",
            "--all",
            "-l",
            "--list",
            "--contains",
            "--no-contains",
            "--merged",
            "--no-merged",
            "--sort",
            "--points-at",
        }
        return cmd[#cmd] == "branch" or M._cmd_contains_options(cmd, branch_pty_options)
    end,
    trigger_redraw = function(cmd)
        return M._cmd_contains_options(cmd, branch_write_command_args)
    end,
}

M.checkout = { trigger_redraw = true }
M["checkout-index"] = { trigger_redraw = true }

---@type trunks.Strategy
M.commit = {
    trigger_redraw = true,
    display_strategy = M.STRATEGIES.BELOW,
    tail = true,
    insert = function(cmd)
        local should_not_enter_insert_options = {
            "--allow-empty",
            "--allow-message",
            "--dry-run",
            "--file",
            "--long",
            "--message",
            "--no-edit",
            "--null",
            "--porcelain",
            "--reuse-message",
            "--short",
            "--squash",
            "-C",
            "-F",
            "-m",
            "-z",
        }
        return not M._cmd_contains_options(cmd, should_not_enter_insert_options)
    end,
}

M.diff = { display_strategy = M.STRATEGIES.FULL }
M.fetch = { trigger_redraw = true }
M.merge = { insert = true, trigger_redraw = true }

M.notes = {
    display_strategy = M.STRATEGIES.BELOW,
    insert = function(cmd)
        local should_not_enter_insert_options =
            { "--message", "-m", "copy", "get-ref", "list", "merge", "prune", "remove", "show" }
        return not M._cmd_contains_options(cmd, should_not_enter_insert_options)
    end,
}

M.pull = { trigger_redraw = true, display_strategy = M.STRATEGIES.BELOW, tail = true }
M.push = { trigger_redraw = true, display_strategy = M.STRATEGIES.BELOW, tail = true }
M.rebase = { insert = true, trigger_redraw = true, display_strategy = M.STRATEGIES.BELOW }
M.reflog = { display_strategy = M.STRATEGIES.FULL }
M.reset = { trigger_redraw = true }
M.revert = { trigger_redraw = true }
M.show = { display_strategy = M.STRATEGIES.FULL }
M.stage = { trigger_redraw = true }

M.stash = {
    display_strategy = M.STRATEGIES.BELOW,
    trigger_redraw = function(cmd)
        local read_only_commands = { "list", "show" }
        if M._cmd_contains_options(cmd, read_only_commands) then
            return false
        end
        return true
    end,
}

M.status = { pty = true }
M.switch = { trigger_redraw = true }
M.whatchanged = { insert = true }

return M
