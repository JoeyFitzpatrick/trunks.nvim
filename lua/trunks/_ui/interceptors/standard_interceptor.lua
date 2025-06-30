local M = {}

---@param command_builder trunks.Command
function M.render(command_builder)
    local cmd = command_builder:build()
    local bufnr = require("trunks._ui.elements").new_buffer({ filetype = "git" })
    require("trunks._ui.keymaps.git_filetype_keymaps").set_keymaps(bufnr)
    require("trunks._ui.stream").stream_lines(bufnr, cmd, {})
end

return M
