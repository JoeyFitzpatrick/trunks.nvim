local M = {}

local utils = require("trunks._ui.trunks_commands.utils")
local async = require("trunks._core.async")
local run_cmd = require("trunks._core.run_cmd").run_cmd

---@param hash string | nil
local function run_instant_fixup(hash)
    if not hash or not utils.validate_hash(hash) then
        return
    end

    local command_builder = require("trunks._core.command").base_command(
        string.format(
            "commit --fixup=%s && GIT_SEQUENCE_EDITOR=true git rebase -i --autostash --autosquash %s^",
            hash,
            hash
        )
    )
    return run_cmd(command_builder, { rerender = true })
end

---@return string | nil
local function choose_instant_fixup_commit()
    local bufnr = require("trunks._ui.elements").new_buffer({ buffer_name = "TrunksCommitInstantFixupChoose" })
    require("trunks._ui.home_options.log").set_lines(bufnr, { ui_types = { "commit_instant_fixup" } })
    require("trunks._ui.keymaps.set").safe_set_keymap("n", "<enter>", function()
        local hash = vim.api.nvim_get_current_line():match("^%x+")
        require("trunks._core.register").deregister_buffer(bufnr, { delete_win_buffers = false })
        run_instant_fixup(hash)
    end, { buffer = bufnr, nowait = true })
end

---@param hash string | nil
function M.commit_instant_fixup(hash)
    async.run_async(function()
        if not require("trunks._core.git").is_anything_staged() then
            local should_stage_all =
                require("trunks._ui.utils.confirm").confirm_choice("No changes are staged. Stage all changes?")
            if should_stage_all then
                run_cmd("stage --all")
            end
        end

        -- If after running stage --all, if there are still no staged changes
        -- (maybe there were no changes to begin with), just return
        if not require("trunks._core.git").is_anything_staged() then
            return "Unable to fixup commit with no changes.", 1
        end

        if not hash or not utils.validate_hash(hash) then
            choose_instant_fixup_commit()
            return
        end

        run_instant_fixup(hash)
    end)
end

return M
