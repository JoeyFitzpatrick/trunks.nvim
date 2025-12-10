---@alias trunks.DisplayStrategy "above" | "below" | "right" | "left" | "full" | "quiet"
---@alias trunks.DisplayStrategyParser fun(cmd: string[]): trunks.DisplayStrategy
---@alias trunks.DisplayStrategyBoolParser fun(cmd: string[]): boolean

---@class trunks.Strategy
---@field display_strategy? trunks.DisplayStrategy | trunks.DisplayStrategyParser
---@field insert? boolean | trunks.DisplayStrategyBoolParser
---@field trigger_redraw? boolean | trunks.DisplayStrategyBoolParser
---@field enter? boolean
---@field win_size? number
---@field term? boolean
---@field pty? boolean

local M = {}

local function tbls_overlap(t1, t2)
    for _, item in ipairs(t2) do
        if vim.tbl_contains(t1, item) then
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
    return tbls_overlap(cmd, full_screen_options)
end

---@param cmd string[]
---@param custom_strategy? trunks.Strategy
---@return trunks.Strategy
function M.get_strategy(cmd, custom_strategy)
    local base_cmd = cmd[2]
    if base_cmd and vim.startswith(cmd[2], "-") then
        base_cmd = cmd[3]
    end
    if not base_cmd then
        return M.default
    end
    local strategy = vim.tbl_extend("force", M.default, M[base_cmd] or {}, custom_strategy or {})
    -- Passing --quiet to a command will stop the output from displaying.
    -- This is only for "write" commands like "commit" or "checkout",
    -- since it doesn't make sense to quiet a "read" command like log or status.
    if vim.tbl_contains(cmd, "--quiet") and strategy.trigger_redraw then
        strategy.display_strategy = M.STRATEGIES.QUIET
    end
    return strategy
end

---@type table<string, trunks.DisplayStrategy>
M.STRATEGIES = {
    ABOVE = "above",
    BELOW = "below",
    RIGHT = "right",
    LEFT = "left",
    FULL = "full",
    QUIET = "quiet",
}

M.default = {
    display_strategy = M.STRATEGIES.BELOW,
    insert = false,
    trigger_redraw = false,
    pty = true,
}

---@type trunks.Strategy
M.add = {
    display_strategy = function(cmd)
        if is_full_screen_command(cmd) then
            return M.STRATEGIES.FULL
        end
        return M.STRATEGIES.BELOW
    end,
    insert = is_full_screen_command,
    trigger_redraw = true,
}

M.annotate = { insert = true }

---@type trunks.Strategy
M.branch = {
    display_strategy = M.STRATEGIES.BELOW,
    trigger_redraw = function(cmd)
        local args_that_trigger_redraw = {
            "-d",
            "--delete",
            "-m",
            "--move",
            "-M",
            "-c",
            "--copy",
        }
        return tbls_overlap(args_that_trigger_redraw, cmd)
    end,
}

M.checkout = { trigger_redraw = true }
M["checkout-index"] = { trigger_redraw = true }

---@type trunks.Strategy
M.commit = {
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
        return not tbls_overlap(cmd, should_not_enter_insert_options)
    end,
    trigger_redraw = true,
}

M.config = { insert = true }
M.diff = { display_strategy = M.STRATEGIES.RIGHT, insert = false, pty = false }
M.fetch = { display_strategy = M.STRATEGIES.BELOW, trigger_redraw = true }
M.merge = { insert = true, trigger_redraw = true }

M.notes = {
    display_strategy = M.STRATEGIES.BELOW,
    insert = function(cmd)
        local should_not_enter_insert_options =
            { "--message", "-m", "copy", "get-ref", "list", "merge", "prune", "remove", "show" }
        return not tbls_overlap(cmd, should_not_enter_insert_options)
    end,
}

M.pull = { trigger_redraw = true }
M.push = { trigger_redraw = true }
M.rebase = { insert = true, trigger_redraw = true }
M.reset = { trigger_redraw = true }
M.revert = { trigger_redraw = true }
M.show = { display_strategy = M.STRATEGIES.FULL, insert = true, pty = false }
M.stage = { trigger_redraw = true }

M.stash = {
    trigger_redraw = function(cmd)
        local read_only_commands = { "list", "show" }
        if tbls_overlap(cmd, read_only_commands) then
            return false
        end
        return true
    end,
}

M.switch = { trigger_redraw = true }
M.whatchanged = { insert = true }

return M
