--- All `trunks` command definitions.

local PREFIX = "G"

---@param input_args vim.api.keyset.create_user_command.command_args
local function run_git_command(input_args)
    local cmd = require("trunks._core.parse_command").parse(input_args)
    local Command = require("trunks._core.command")
    local command_builder = Command.base_command(cmd)

    if input_args.bang then
        local bufnr = require("trunks._ui.elements").new_buffer({ hidden = true })
        require("trunks._ui.elements").terminal(
            bufnr,
            command_builder:build(),
            { display_strategy = "full", insert = true }
        )
        return
    end

    local ui_function = require("trunks._ui.interceptors").get_ui(command_builder)
    if ui_function then
        ui_function(command_builder)
    else
        local bufnr = require("trunks._ui.elements").new_buffer({ hidden = true })
        require("trunks._ui.elements").terminal(bufnr, command_builder:build())
    end
end

---@param input_args vim.api.keyset.create_user_command.command_args
local function run_trunks_command(input_args)
    require("trunks._ui.trunks_commands").run_trunks_cmd(input_args)
end

vim.api.nvim_create_user_command(PREFIX, function(input_args)
    require("trunks")
    run_git_command(input_args)
end, {
    nargs = "*",
    desc = "Trunks's git command API. Mostly the same as the Git API.",
    bang = true, -- with a bang, always run command in terminal mode (no ui)
    range = true, -- some commands, like ":G log -L", work on a range of lines
    complete = function(arglead, cmdline)
        local completion = require("trunks._completion").complete_command(arglead, cmdline, PREFIX)
        return vim.tbl_filter(function(val)
            return vim.startswith(val, arglead)
        end, completion)
    end,
})

vim.api.nvim_create_user_command("Trunks", function(input_args)
    require("trunks")
    run_trunks_command(input_args)
end, {
    nargs = "*",
    desc = "Trunks command API. For commands that aren't native git commands.",
    range = true,
    complete = function(arglead, cmdline)
        local completion = require("trunks._completion").complete_command(arglead, cmdline, "Trunks")
        return vim.tbl_filter(function(val)
            return vim.startswith(val, arglead)
        end, completion)
    end,
})

require("trunks._core.nested-buffers").prevent_nested_buffers()
