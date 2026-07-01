local M = {}

local popup = require("trunks._ui.popups.popup")

---@class trunks.DiffPopupOpts
---@field left_commit? string
---@field right_commit? string

---@param filename string
---@param opts trunks.DiffPopupOpts
---@return { basic: trunks.PopupMapping[], edit: trunks.PopupMapping[] }
local function get_keymaps_with_descriptions(filename, opts)
    local keymaps = require("trunks._ui.keymaps.base").get_keymaps(nil, "diff_popup", { popup = true })
    local descriptions = require("trunks._constants.keymap_descriptions").long_descriptions.diff_popup
    local mappings = { basic = {}, edit = {} }

    local left_commit = opts.left_commit
    local right_commit = opts.right_commit
    -- When a left commit is given, split_diff opens both revisions itself, so we
    -- only need an empty tab. Otherwise we diff the working-tree file against a commit.
    local is_commit_diff = left_commit ~= nil

    ---@param subcommand string
    ---@param split_type "below" | "right"
    local function open_split_diff(subcommand, split_type)
        if is_commit_diff then
            vim.api.nvim_exec2("tabnew", {})
        else
            vim.api.nvim_exec2("tabnew | e " .. filename, {})
        end
        require("trunks._ui.interceptors.split_diff").split_diff(subcommand, {
            filepath = filename,
            left_commit = left_commit,
            right_commit = right_commit,
            split_type = split_type,
        })
    end

    local keymap_command_map = {
        basic = {
            [keymaps.vdiff] = function()
                open_split_diff("vdiff", "right")
            end,
            [keymaps.hdiff] = function()
                open_split_diff("hdiff", "below")
            end,
            [keymaps.term] = function()
                if is_commit_diff then
                    vim.cmd(string.format("G diff %s %s -- %s", left_commit, right_commit, filename))
                else
                    vim.cmd("G diff -- " .. filename)
                end
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
---@param opts? trunks.DiffPopupOpts
---@return integer -- bufnr
function M.render(filename, opts)
    local maps = get_keymaps_with_descriptions(filename, opts or {})

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
