local M = {}

---@param command_builder trunks.Command
---@param command_type "diff" | "show"
function M.render(command_builder, command_type)
    local cmd = command_builder:build()
    local base_cmd = vim.split(cmd, " ")[1]
    local bufnr = require("trunks._ui.elements").new_buffer({})
    require("trunks._ui.elements").terminal(bufnr, cmd, { display_strategy = "full" })

    -- For diff commands, parse and store the refs being compared
    if command_type == "diff" then
        local refs = require("trunks._ui.interceptors.diff_ref_parser").parse_diff_refs(cmd)
        if refs then
            vim.b[bufnr].trunks_diff_from = refs.from
            vim.b[bufnr].trunks_diff_to = refs.to
        end
    end

    require("trunks._ui.keymaps.git_filetype_keymaps").set_keymaps(bufnr)
    require("trunks._core.autocmds").execute_user_autocmds({ ui_type = "buffer", ui_name = base_cmd })
end

return M
