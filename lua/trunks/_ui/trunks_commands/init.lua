local M = {}

---@param hash string | nil
local function drop_commit(hash)
    local MIN_HASH_LENGTH = 7
    if not hash or #hash < MIN_HASH_LENGTH then
        return
    end
    hash = hash:sub(1, 7)

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

    require("trunks._core.run_cmd").run_cmd(command_builder)
end

---@param input_args vim.api.keyset.create_user_command.command_args
function M.run_trunks_cmd(input_args)
    local cmd = input_args.args
    if cmd:match("^drop%-commit") then
        local hash = vim.split(cmd, " ")[2]
        return drop_commit(hash)
    end
end

return M
