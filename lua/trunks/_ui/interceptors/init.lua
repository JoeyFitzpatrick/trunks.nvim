local M = {}

---@type table<string, fun(command_builder?: trunks.Command)>
local cmd_ui_map = {
    blame = function(command_builder)
        require("trunks._ui.interceptors.blame").render(command_builder)
    end,
    branch = function(command_builder)
        local strategy = require("trunks._constants.command_strategies").get_strategy(command_builder:build())
        if strategy.pty then
            local bufnr = require("trunks._ui.elements").new_buffer({ hidden = true })
            require("trunks._ui.home_options.branch").render(bufnr, {
                command_builder = command_builder,
                ui_types = { "branch" },
            })
        end
        return nil
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
        require("trunks._ui.interceptors.standard_interceptor").render(command_builder, "help")
        -- Setting the filetype to man add nice highlighting.
        -- It also makes the "q" keymap exit neovim if this is the last buffer, so we need to set it again
        vim.bo["filetype"] = "man"

        require("trunks._ui.keymaps.set").set_q_keymap(0)
    end,
    log = function(command_builder)
        local cmd = command_builder:build()
        if require("trunks._core.texter").has_options(cmd, { "--graph" }) then
            require("trunks._ui.elements").terminal(cmd, { display_strategy = "full", insert = true })
            return
        end
        local bufnr = require("trunks._ui.elements").new_buffer({ buffer_name = os.tmpname() .. "/TrunksLog" })
        require("trunks._ui.home_options.log").render(
            bufnr,
            { start_line = 2, command_builder = command_builder, ui_types = { "log" } }
        )
    end,
    mergetool = function()
        require("trunks._ui.interceptors.mergetool").render()
    end,
    reflog = function(command_builder)
        require("trunks._ui.interceptors.reflog").render(command_builder)
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
---@return fun(command_builder: trunks.Command) | nil
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
