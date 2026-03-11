local M = {}

---@param branch_name string
function M.render(branch_name)
    local keymaps = require("trunks._ui.keymaps.base").get_keymaps(nil, "merge_rebase_popup", { popup = true })
    local descriptions = require("trunks._constants.keymap_descriptions").long_descriptions.merge_rebase_popup
    local run_cmd = require("trunks._core.run_cmd")

    ---@type trunks.PopupColumn[]
    local columns = {
        {
            title = "From branch",
            rows = {
                {
                    keys = keymaps.merge,
                    description = descriptions.merge,
                    action = function()
                        run_cmd.run_hidden_cmd("merge " .. branch_name, { rerender = true })
                    end,
                },
                {
                    keys = keymaps.rebase,
                    description = descriptions.rebase,
                    action = function()
                        run_cmd.run_hidden_cmd("rebase " .. branch_name, { rerender = true })
                    end,
                },
            },
        },
        {
            title = "From remote (origin/" .. branch_name .. ")",
            rows = {
                {
                    keys = keymaps.merge_remote,
                    description = descriptions.merge_remote,
                    action = function()
                        run_cmd.run_hidden_cmd("merge origin/" .. branch_name, { rerender = true })
                    end,
                },
                {
                    keys = keymaps.rebase_remote,
                    description = descriptions.rebase_remote,
                    action = function()
                        run_cmd.run_hidden_cmd("rebase origin/" .. branch_name, { rerender = true })
                    end,
                },
            },
        },
    }

    require("trunks._ui.popups.popup").render_popup({
        buffer_name = "TrunksMergeRebasePopup",
        title = "Merge/Rebase from " .. branch_name,
        columns = columns,
    })
end

return M
