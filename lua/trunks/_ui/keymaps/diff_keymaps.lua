local M = {}

---@param bufnr integer
function M.set_diff_keymaps(bufnr)
    local keymaps = require("trunks._ui.keymaps.base").get_keymaps(bufnr, "trunks_diff", {})
end

return M
