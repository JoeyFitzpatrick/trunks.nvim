local M = {}

---@param command_builder trunks.Command
function M.render(command_builder)
    local cmd = command_builder:build()
    local bufnr = require("trunks._ui.elements").new_buffer({ filetype = "git" })
    require("trunks._ui.keymaps.git_filetype_keymaps").set_keymaps(bufnr)

    -- Check if this is a diff command
    local is_diff_command = command_builder.base and command_builder.base:match("^diff")

    if is_diff_command then
        local diff_syntax = require("trunks._ui.diff_syntax")
        -- For diff commands, use streaming transforms for better performance:
        -- 1. Strip diff markers as lines stream in (transform_line)
        -- 2. Apply diff line highlighting immediately (highlight_line)
        -- 3. Apply treesitter syntax on exit (on_exit)
        require("trunks._ui.stream").stream_lines(bufnr, cmd, {
            transform_line = diff_syntax.transform_line,
            highlight_line = diff_syntax.highlight_line,
            on_exit = function(buf)
                vim.schedule(function()
                    diff_syntax.apply_treesitter_syntax(buf)
                end)
            end,
        })
    else
        require("trunks._ui.stream").stream_lines(bufnr, cmd, {})
    end
end

return M
