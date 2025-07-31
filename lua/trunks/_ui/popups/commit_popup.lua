local M = {}

local popup = require("trunks._ui.popups.popup")

---@param bufnr integer
---@param ui_type string
---@return { basic: trunks.PopupMapping[], edit: trunks.PopupMapping[] }
local function get_keymaps_with_descriptions(bufnr, ui_type)
    local keymaps = require("trunks._ui.keymaps.base").get_keymaps(bufnr, "commit_popup", { popup = true })
    local descriptions = require("trunks._constants.keymap_descriptions").long_descriptions[ui_type]
    local mappings = { basic = {}, edit = {} }

    local keymap_command_map = {
        basic = {
            [keymaps.commit] = "G commit",
            [keymaps.commit_amend] = "G commit --amend",
            [keymaps.commit_amend_reuse_message] = "G commit --amend --reuse-message HEAD --no-verify",
            [keymaps.commit_dry_run] = "G commit --dry-run",
            [keymaps.commit_no_verify] = "G commit --no-verify",
        },
        edit = {
            [keymaps.commit_instant_fixup] = "Trunks commit-instant-fixup",
        },
    }

    for name, keys in pairs(keymaps) do
        if keys and keymap_command_map.basic[keys] then
            table.insert(mappings.basic, {
                keys = keys,
                description = descriptions[name],
                -- Yes, using keys as the key. Pretty disgusting and should be fixed.
                action = keymap_command_map.basic[keys],
            })
        end
        if keys and keymap_command_map.edit[keys] then
            table.insert(mappings.edit, {
                keys = keys,
                description = descriptions[name],
                action = keymap_command_map.edit[keys],
            })
        end
    end

    return mappings
end

---@return integer -- bufnr
function M.render()
    local bufnr = require("trunks._ui.elements").new_buffer({
        buffer_name = "TrunksCommitPopup",
        win_config = { split = "below" },
    })

    local maps = get_keymaps_with_descriptions(bufnr, "commit_popup")
    popup.render(bufnr, {
        { title = "Commit", rows = maps.basic },
        { title = "Edit", rows = maps.edit },
    })
    return bufnr
end

return M
