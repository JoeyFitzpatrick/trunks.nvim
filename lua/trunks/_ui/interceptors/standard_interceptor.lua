local M = {}

---@param command_builder trunks.Command
---@param command_type "help" | "diff" | "show"
function M.render(command_builder, command_type)
    local cmd = command_builder:build()
    local base_cmd = vim.split(cmd, " ")[1]
    local bufnr = require("trunks._ui.elements").new_buffer({ filetype = "git" })

    -- For diff commands, parse and store the refs being compared
    if command_type == "diff" then
        local refs = require("trunks._ui.interceptors.diff_ref_parser").parse_diff_refs(cmd)
        if refs then
            vim.b[bufnr].trunks_diff_from = refs.from
            vim.b[bufnr].trunks_diff_to = refs.to
        end
    end

    if command_type ~= "help" then
        require("trunks._ui.keymaps.git_filetype_keymaps").set_keymaps(bufnr)
    end

    local diff_commands = { "diff", "show" }
    local is_diff_command = false
    if command_builder.base then
        for _, diff_command in ipairs(diff_commands) do
            if vim.startswith(command_builder.base, diff_command) then
                is_diff_command = true
            end
        end
    end

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
    require("trunks._core.autocmds").execute_user_autocmds({ ui_type = "buffer", ui_name = base_cmd })
end

return M
