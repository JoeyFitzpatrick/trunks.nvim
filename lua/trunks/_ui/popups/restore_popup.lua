local M = {}

---@param filepath string
---@param commit string
---@return integer -- bufnr
function M.render(filepath, commit)
    local keymaps = require("trunks._ui.keymaps.base").get_keymaps(nil, "restore_popup", { popup = true })
    local descriptions = require("trunks._constants.keymap_descriptions").long_descriptions.restore_popup
    local safe_filename = "'" .. filepath .. "'"

    ---@type trunks.PopupMapping[]
    local mappings = {
        {
            keys = keymaps.restore_from_commit,
            description = descriptions.restore_from_commit,
            action = function()
                local output, exit_code =
                    require("trunks._core.run_cmd").run_cmd(string.format("restore -s %s %s", commit, safe_filename))
                if exit_code == 0 then
                    vim.notify(string.format("Restored %s from %s", filepath, commit), vim.log.levels.INFO)
                else
                    vim.notify(
                        string.format(
                            output[1] or string.format("Unable to restore %s from %s", filepath, commit),
                            vim.log.levels.ERROR
                        )
                    )
                end
            end,
        },
        {
            keys = keymaps.restore_from_commit_before,
            description = descriptions.restore_from_commit_before,
            action = function()
                local output, exit_code =
                    require("trunks._core.run_cmd").run_cmd(string.format("restore -s %s^ %s", commit, safe_filename))
                if exit_code == 0 then
                    vim.notify(string.format("Restored %s from %s^", filepath, commit), vim.log.levels.INFO)
                else
                    vim.notify(
                        string.format(
                            output[1] or string.format("Unable to restore %s from %s^", filepath, commit),
                            vim.log.levels.ERROR
                        )
                    )
                end
            end,
        },
    }

    local bufnr = require("trunks._ui.popups.popup").render_popup({
        buffer_name = "TrunksRestorePopup",
        title = string.format("Restore %s", filepath),
        mappings = mappings,
    })

    return bufnr
end

return M
