local M = {}

---@param command_builder trunks.Command
function M.render(command_builder)
    local cmd = command_builder:build()
    local bufnr = require("trunks._ui.elements").new_buffer({ filetype = "git" })
    require("trunks._ui.keymaps.git_filetype_keymaps").set_keymaps(bufnr)

    -- Check if this is a diff command
    local is_diff_command = command_builder.base and command_builder.base:match("^diff")

    if is_diff_command then
        -- For diff commands, wait for content to load then apply syntax highlighting
        require("trunks._ui.stream").stream_lines(bufnr, cmd, {
            on_exit = function()
                vim.schedule(function()
                    require("trunks._ui.diff_syntax").apply_syntax(bufnr)
                end)
            end,
        })
    else
        require("trunks._ui.stream").stream_lines(bufnr, cmd, {})
    end
end

return M
