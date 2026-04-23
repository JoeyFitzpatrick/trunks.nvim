local M = {}

---@alias UiFunction fun(command_builder: trunks.Command, input_args: vim.api.keyset.create_user_command.command_args)

---@type table<string, UiFunction>
local cmd_ui_map = {
    blame = function(command_builder)
        require("trunks._ui.interceptors.blame").render(command_builder)
    end,
    branch = function(command_builder, input_args)
        local strategy = require("trunks._constants.command_strategies").get_strategy(command_builder:build())
        if strategy.pty then
            local bufnr = require("trunks._ui.elements").new_buffer({ hidden = true })
            require("trunks._ui.home_options.branch").render(bufnr, {
                command_builder = command_builder,
                ui_types = { "branch" },
                input_args = input_args,
            })
        end
    end,
    difftool = function(command_builder)
        require("trunks._ui.interceptors.difftool").render(command_builder)
    end,
    grep = function(command_builder)
        require("trunks._ui.interceptors.grep").render(command_builder)
    end,
    help = function(command_builder)
        -- col -b is needed to remove bad characters from --help output
        command_builder:add_args("| col -b")
        local get_lines = function()
            local lines = require("trunks._core.run_cmd").run_cmd(command_builder)
            return lines
        end
        local bufnr = require("trunks._ui.elements").new_buffer({
            -- Setting the filetype to man add nice highlighting.
            -- It also makes the "q" keymap exit neovim if this is the last buffer, so we need to set it again
            filetype = "man",
            show = true,
            lines = get_lines,
        })
        require("trunks._ui.keymaps.set").set_q_keymap(bufnr)
    end,
    log = function(command_builder, input_args)
        local bufnr = require("trunks._ui.elements").new_buffer({ buffer_name = os.tmpname() .. "/TrunksLog" })
        require("trunks._ui.home_options.log").render(
            bufnr,
            { start_line = 2, command_builder = command_builder, ui_types = { "log" }, input_args = input_args }
        )
    end,
    mergetool = function()
        require("trunks._ui.interceptors.mergetool").render()
    end,
    reflog = function(command_builder, input_args)
        require("trunks._ui.interceptors.reflog").render(command_builder, input_args)
    end,
}

local standard_output_commands = {
    "diff",
    "show",
}

for _, command in ipairs(standard_output_commands) do
    cmd_ui_map[command] = function(command_builder)
        require("trunks._ui.interceptors.standard_interceptor").render(command_builder, command)
    end
end

---@param command_builder trunks.Command
---@return fun(command_builder: trunks.Command, input_args: vim.api.keyset.create_user_command.command_args) | nil
function M.get_ui(command_builder)
    local cmd = command_builder.base
    if not cmd then
        return function()
            require("trunks._ui.home").open()
        end
    end

    local subcommand = cmd:match("%S+")
    if not subcommand then
        return function()
            require("trunks._ui.home").open()
        end
    end

    local is_help_command = cmd:match("%-h%s*$") or cmd:match("%-%-help%s*$")
    if is_help_command then
        return cmd_ui_map.help
    end

    return cmd_ui_map[subcommand]
end

return M
