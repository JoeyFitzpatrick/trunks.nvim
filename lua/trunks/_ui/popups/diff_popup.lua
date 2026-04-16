local M = {}

local popup = require("trunks._ui.popups.popup")

---@param filename string
---@return { basic: trunks.PopupMapping[], edit: trunks.PopupMapping[] }
local function get_keymaps_with_descriptions(filename)
    local keymaps = require("trunks._ui.keymaps.base").get_keymaps(nil, "diff_popup", { popup = true })
    local descriptions = require("trunks._constants.keymap_descriptions").long_descriptions.diff_popup
    local mappings = { basic = {}, edit = {} }

    local keymap_command_map = {
        basic = {
            [keymaps.vdiff] = function()
                vim.api.nvim_exec2("e " .. filename, {})
                require("trunks._ui.interceptors.split_diff").split_diff(
                    "vdiff",
                    { filepath = filename, split_type = "right" }
                )
            end,
            [keymaps.hdiff] = function()
                vim.api.nvim_exec2("e " .. filename, {})
                require("trunks._ui.interceptors.split_diff").split_diff(
                    "hdiff",
                    { filepath = filename, split_type = "below" }
                )
            end,
            [keymaps.term] = function()
                vim.cmd("G diff -- " .. filename)
            end,
        },
    }

    for name, keys in pairs(keymaps) do
        if keys and keymap_command_map.basic[keys] then
            table.insert(mappings.basic, {
                keys = keys,
                description = descriptions[name],
                action = keymap_command_map.basic[keys],
            })
        end
    end

    return mappings
end

---@param filename string
---@return integer -- bufnr
function M.render(filename)
    local maps = get_keymaps_with_descriptions(filename)

    -- Flatten mappings for render_popup
    local mappings = {}
    for _, mapping in ipairs(maps.basic) do
        table.insert(mappings, mapping)
    end

    local bufnr = popup.render_popup({
        title = "Diff",
        buffer_name = "TrunksDiffPopup",
        columns = {
            { title = "Diff", rows = maps.basic },
        },
    })
    return bufnr
end

return M
