local M = {}

---@param branch_name string
function M.render(branch_name)
    local keymaps = require("trunks._ui.keymaps.base").get_keymaps(nil, "merge_rebase_popup", { popup = true })
    local descriptions = require("trunks._constants.keymap_descriptions").long_descriptions.merge_rebase_popup
    local run_cmd = require("trunks._core.run_cmd")

    local remote_output, remote_err =
        run_cmd.run_cmd("config --get branch." .. branch_name .. ".remote", { no_pager = true })
    local remote = (remote_err == 0 and remote_output[1]) or "origin"

    local head_output, head_err =
        run_cmd.run_cmd("symbolic-ref refs/remotes/" .. remote .. "/HEAD", { no_pager = true })
    local remote_ref
    if head_err == 0 and head_output[1] then
        local head_branch = head_output[1]:match("refs/remotes/" .. remote .. "/(.+)")
        remote_ref = remote .. "/" .. (head_branch or branch_name)
    else
        remote_ref = remote .. "/" .. branch_name
    end

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
            title = "From remote (" .. remote_ref .. ")",
            rows = {
                {
                    keys = keymaps.merge_remote,
                    description = descriptions.merge_remote,
                    action = function()
                        run_cmd.run_hidden_cmd("merge " .. remote_ref, { rerender = true })
                    end,
                },
                {
                    keys = keymaps.rebase_remote,
                    description = descriptions.rebase_remote,
                    action = function()
                        run_cmd.run_hidden_cmd("rebase " .. remote_ref, { rerender = true })
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
