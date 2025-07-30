local M = {}

local MIN_HASH_LENGTH = 7

---@param hash string | nil
---@return boolean
local function validate_hash(hash)
    return type(hash) == "string" and #hash >= MIN_HASH_LENGTH
end

---@param hash string | nil
local function commit_drop(hash)
    if not hash or not validate_hash(hash) then
        return
    end
    hash = hash:sub(1, MIN_HASH_LENGTH)

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

---@param hash string
local function commit_instant_fixup(hash)
    if not hash or not validate_hash(hash) then
        return
    end
    local run_cmd = require("trunks._core.run_cmd").run_cmd

    if not require("trunks._core.git").is_anything_staged() then
        if require("trunks._ui.utils.confirm").confirm_choice("No changes are staged. Stage all changes?") then
            run_cmd("stage --all")
        end
    end

    -- If after running stage --all, if there are still no staged changes
    -- (maybe there were no changes to begin with), just return
    if not require("trunks._core.git").is_anything_staged() then
        return "Unable to fixup commit with no changes.", 1
    end

    local command_builder = require("trunks._core.command").base_command(
        string.format(
            "commit --fixup=%s && GIT_SEQUENCE_EDITOR=true git rebase -i --autostash --autosquash %s^",
            hash,
            hash
        )
    )
    return run_cmd(command_builder, { rerender = true })
end

---@param ok_text string | nil
---@param error_text string[] | string
---@param error_code integer | nil
local function handle_output(ok_text, error_text, error_code)
    local is_ok = error_code == nil or error_code == 0
    if is_ok then
        if ok_text then
            vim.notify(ok_text, vim.log.levels.INFO)
        end
        return
    end
    if type(error_text) == "table" then
        error_text = table.concat(error_text, "\n")
    end
    vim.notify(error_text, vim.log.levels.ERROR)
end

---@type table<string, fun(cmd: string)>
local cmd_map = {
    ["commit-drop"] = function(cmd)
        local hash = vim.split(cmd, " ")[2]
        local output, exit_code = commit_drop(hash)
        hash = hash:sub(1, MIN_HASH_LENGTH)
        local error_text = output or ("Unable to commit drop " .. hash)
        handle_output("Dropped commit " .. hash .. " and rebased.", error_text, exit_code)
    end,

    ["commit-instant-fixup"] = function(cmd)
        local hash = vim.split(cmd, " ")[2]
        local output, exit_code = commit_instant_fixup(hash)
        hash = hash:sub(1, MIN_HASH_LENGTH)
        local error_text = output or ("Unable to fixup commit " .. hash)
        handle_output("Applied fixup to commit " .. hash .. " and rebased.", error_text, exit_code)
    end,

    ["time-machine"] = function(cmd)
        local filename = vim.split(cmd, " ")[2]
        local output, exit_code = require("trunks._ui.trunks_commands.time_machine").render(filename)
        local error_text = output or "Unable to run time-machine"
        handle_output(nil, error_text, exit_code)
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
    require("trunks._core.async").run_async(function()
        local cmd = input_args.args
        local trunks_command = cmd:match("^%S+")
        if not trunks_command then
            vim.notify("Unable to parse Trunks command " .. (cmd or ""))
        end

        local trunks_command_fn = cmd_map[trunks_command]
        if not trunks_command_fn then
            vim.notify(
                require("trunks._core.texter").surround_with_quotes(trunks_command) .. " is not a Trunks command"
            )
        end

        trunks_command_fn(cmd)
    end)
end

return M
