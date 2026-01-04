local M = {}

local utils = require("trunks._ui.trunks_commands.utils")

---@param hash string | nil
local function commit_drop(hash)
    if not hash or not utils.validate_hash(hash) then
        return
    end
    hash = hash:sub(1, utils.MIN_HASH_LENGTH)

    local command_builder = require("trunks._core.command").base_command(
        string.format("rebase --interactive --autostash --keep-empty --no-autosquash --rebase-merges %s~1", hash)
    )
    command_builder:add_env_var(
        "GIT_SEQUENCE_EDITOR="
            .. require("trunks._core.texter").surround_with_quotes(
                string.format("sed -i -e 's/^pick %s/drop %s/'", hash, hash),
                '"'
            )
    )

    return require("trunks._core.run_cmd").run_cmd(command_builder, { rerender = true })
end

---@type table<string, fun(cmd: string, input_args?: vim.api.keyset.create_user_command.command_args)>
local cmd_map = {
    ["browse"] = function(cmd, input_args)
        require("trunks._ui.trunks_commands.browse").browse(cmd, input_args)
    end,

    ["commit-drop"] = function(cmd)
        local hash = vim.split(cmd, " ")[2]
        local output, exit_code = commit_drop(hash)
        hash = hash:sub(1, utils.MIN_HASH_LENGTH)
        local error_text = output or ("Unable to commit drop " .. hash)
        utils.handle_output("Dropped commit " .. hash .. " and rebased.", error_text, exit_code)
    end,

    ["commit-instant-fixup"] = function(cmd)
        local hash = vim.split(cmd, " ")[2]
        require("trunks._ui.trunks_commands.commit_instant_fixup").commit_instant_fixup(hash)
    end,

    ["diff-qf"] = function(cmd)
        local _, args_start = cmd:find(" ", 1, true)
        local commit = nil
        if args_start then
            commit = cmd:sub(args_start)
        end
        local output, exit_code = require("trunks._ui.trunks_commands.diff_qf").render(commit)
        local error_text = output or ("Unable to display diff for " .. (commit or "unknown commit"))
        utils.handle_output(nil, error_text, exit_code)
    end,

    ["time-machine"] = function(cmd)
        local filename = vim.split(cmd, " ")[2]
        local output, exit_code = require("trunks._ui.trunks_commands.time_machine").render(filename)
        local error_text = output or "Unable to run time-machine"
        utils.handle_output(nil, error_text, exit_code)
    end,

    ["time-machine-next"] = function()
        require("trunks._ui.trunks_commands.time_machine").next(vim.api.nvim_get_current_buf())
    end,

    ["time-machine-previous"] = function()
        require("trunks._ui.trunks_commands.time_machine").previous(vim.api.nvim_get_current_buf())
    end,

    vdiff = function(cmd)
        require("trunks._ui.interceptors.split_diff").split_diff(cmd, "right")
    end,

    hdiff = function(cmd)
        require("trunks._ui.interceptors.split_diff").split_diff(cmd, "below")
    end,
}

---@param input_args vim.api.keyset.create_user_command.command_args
function M.run_trunks_cmd(input_args)
    local cmd = input_args.args
    local trunks_command = cmd:match("^%S+")
    if not trunks_command then
        vim.notify("Unable to parse Trunks command " .. (cmd or ""))
    end

    local trunks_command_fn = cmd_map[trunks_command]
    if not trunks_command_fn then
        vim.notify(require("trunks._core.texter").surround_with_quotes(trunks_command) .. " is not a Trunks command")
    end

    trunks_command_fn(cmd, input_args)
end

return M
