local M = {}

local utils = require("trunks._ui.trunks_commands.utils")
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
    local _, exit_code = run_cmd(command_builder, { rerender = true })
    local ok_text = "Applied fixup to commit " .. hash .. " and rebased"
    local error_text = "Unable to apply fixup to commit " .. hash:sub(1, utils.MIN_HASH_LENGTH)
    utils.handle_output(ok_text, error_text, exit_code)
end

---@return string | nil
local function choose_instant_fixup_commit()
    local bufnr = require("trunks._ui.elements").new_buffer({ buffer_name = "TrunksCommitInstantFixupChoose" })
    require("trunks._ui.home_options.log").set_lines(bufnr, { ui_types = { "commit_instant_fixup" } })
    require("trunks._ui.keymaps.set").safe_set_keymap("n", "<enter>", function()
        -- Log output starts at line 4; no-op if above that line
        local start_line = 4
        local current_cursor_line = vim.api.nvim_win_get_cursor(0)[1]
        if current_cursor_line < start_line then
            return
        end

        local hash = vim.api.nvim_get_current_line():match("^%x+")
        require("trunks._core.register").deregister_buffer(bufnr, { delete_win_buffers = false })
        run_instant_fixup(hash)
    end, { buffer = bufnr, nowait = true })
end

---@param hash string | nil
function M.commit_instant_fixup(hash)
    if not require("trunks._core.git").is_anything_staged() then
        local should_stage_all =
            require("trunks._ui.utils.confirm").confirm_choice("No changes are staged. Stage all changes?")
        if should_stage_all then
            run_cmd("stage --all")
        end
    end

    -- If after running stage check, if there are still no staged changes, just return
    if not require("trunks._core.git").is_anything_staged() then
        vim.notify("Unable to fixup commit with no changes.", vim.log.levels.ERROR)
        return
    end

    if not hash or not utils.validate_hash(hash) then
        choose_instant_fixup_commit()
        return
    end

    run_instant_fixup(hash)
end

return M
