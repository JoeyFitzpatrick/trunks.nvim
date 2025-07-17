local M = {}

local MIN_HASH_LENGTH = 7

---@param hash string | nil
local function drop_commit(hash)
    MIN_HASH_LENGTH = 7
    if not hash or #hash < MIN_HASH_LENGTH then
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

---@param ok_text string
---@param error_text string[] | string
---@param error_code integer | nil
local function handle_output(ok_text, error_text, error_code)
    local is_ok = error_code == nil or error_code == 0
    if is_ok then
        vim.notify(ok_text, vim.log.levels.INFO)
        return
    end
    if type(error_text) == "table" then
        error_text = table.concat(error_text, "\n")
    end
    vim.notify(error_text, vim.log.levels.ERROR)
end

---@param input_args vim.api.keyset.create_user_command.command_args
function M.run_trunks_cmd(input_args)
    local cmd = input_args.args
    if cmd:match("^drop%-commit") then
        local hash = vim.split(cmd, " ")[2]
        local output, error_code = drop_commit(hash)
        hash = hash:sub(1, MIN_HASH_LENGTH)
        local error_text = output or ("Unable to drop commit " .. hash)
        handle_output("Dropped commit " .. hash .. " and rebased.", error_text, error_code)
    end
end

return M
