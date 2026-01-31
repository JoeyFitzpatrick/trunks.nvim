local M = {}

-- Setup base commands
local cmd_types = { "list-mainporcelain", "list-ancillarymanipulators", "list-ancillaryinterrogators", "alias" }
M.commands = vim.fn.systemlist("git --list-cmds=" .. table.concat(cmd_types, ","))
table.sort(M.commands)

function M.get_branches()
    local all_branches_command = "git for-each-ref --format='%(refname:short)' refs/heads/ refs/remotes/"
    local branches = vim.fn.systemlist(all_branches_command)
    if vim.v.shell_error ~= 0 then
        return {}
    end
    table.insert(branches, "HEAD")
    return branches
end

function M._path_completion(base)
    return vim.fn.getcompletion(base, "file")
end

---@param command string
---@return string[]
local function get_git_command_completion(command)
    local flags, exit_code = require("trunks._core.run_cmd").run_cmd(command .. " --git-completion-helper-all")

    if exit_code ~= 0 then
        return {}
    end
    return vim.split(flags[1], " ")
end

--- Takes a git/trunks command in command mode, and returns completion options.
---@param arglead string
---@param cmdline string
---@param command_type "G" | "Trunks"
---@return string[]
M.complete_command = function(arglead, cmdline, command_type)
    -- Find where the command (G or Trunks) appears in cmdline and extract args after it
    -- This handles cases like ":tab G diff" or ":vertical Trunks status"
    -- Match the command name followed by whitespace, then capture everything after
    local args_str = cmdline:match(command_type .. "%s+(.*)") or ""

    -- Parse the arguments
    local words = {}
    for word in args_str:gmatch("%S+") do
        table.insert(words, word)
    end

    local command, subcommand = words[1], words[2]

    if not command then
        if command_type == "G" then
            return M.commands
        elseif command_type == "Trunks" then
            return require("trunks._constants.trunks_command_options").commands
        else
            -- Shouldn't be possible to get here, but if so let's not crash
            return {}
        end
    end

    local completion_type
    if command_type == "G" then
        completion_type = require("trunks._constants.git_command_options")[command]
    elseif command_type == "Trunks" then
        completion_type = require("trunks._constants.trunks_command_options").options[command]
    end

    -- If a "-" is typed, provide flag completion, e.g. "--no-verify"
    if arglead:sub(1, 1) == "-" then
        -- Two-word commands need both command words to get flag completion
        if completion_type == "subcommand" and subcommand then
            return get_git_command_completion(command .. " " .. subcommand)
        end
        return get_git_command_completion(command)
    end

    -- if "<space>--<space>" is typed, that always means use filepath completion
    if cmdline:match(" %-%- ") then
        return M._path_completion(arglead) or {}
    end

    if not completion_type then
        return {}
    end

    if completion_type == "branch" then
        return M.get_branches()
    end

    if completion_type == "filepath" then
        return M._path_completion(arglead) or {}
    end

    -- Only get two-word completion (e.g. "git stash apply") if we don't already have two words
    if completion_type == "subcommand" and not subcommand then
        return get_git_command_completion(command)
    end

    return completion_type.options or {}
end

return M
