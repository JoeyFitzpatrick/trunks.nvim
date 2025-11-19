local M = {}

---@type table<string, fun(command_builder?: trunks.Command)>
local cmd_ui_map = {
    blame = function(command_builder)
        require("trunks._ui.interceptors.blame").render(command_builder)
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

-- Keeping these out of the UI map, so that commands like "stash list" don't render UI
local stash_render = function()
    local bufnr = require("trunks._ui.elements").new_buffer({ buffer_name = os.tmpname() .. "/TrunksStash" })
    return require("trunks._ui.home_options.stash").render(bufnr, { ui_types = { "stash" } })
end

local standard_output_commands = {
    "diff",
    "show",
}

for _, command in ipairs(standard_output_commands) do
    cmd_ui_map[command] = function(command_builder)
        require("trunks._ui.interceptors.standard_interceptor").render(command_builder, command)
    end
end

local BRANCH_UI_OPTIONS = {
    "branch",
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

--- Some branch commands, like `git branch new-branch old-branch`,
--- should not open the special branch UI, and just run in terminal mode.
---@param command_builder trunks.Command
---@return function | nil
local function branch_interceptor(command_builder)
    local has_only_ui_options = require("trunks._core.texter").only_has_options(command_builder, BRANCH_UI_OPTIONS)
    if has_only_ui_options then
        return function(branch_command_builder)
            local bufnr = require("trunks._ui.elements").new_buffer({
                buffer_name = os.tmpname() .. "/TrunksBranch",
                win_config = { split = "below" },
            })
            require("trunks._ui.home_options.branch").render(
                bufnr,
                { command_builder = branch_command_builder, ui_types = { "branch" } }
            )
            -- By default branch UI "q" map will go back to last buffer, but in a split we just want to close it
            require("trunks._ui.keymaps.set").set_q_keymap(bufnr)
        end
    end
    return nil
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

    if cmd:match("^stash%s*$") then
        return stash_render
    end
    if vim.startswith(cmd, "branch") then
        -- If this is nil, fall back to terminal mode
        return branch_interceptor(command_builder)
    end
    return cmd_ui_map[subcommand]
end

return M
