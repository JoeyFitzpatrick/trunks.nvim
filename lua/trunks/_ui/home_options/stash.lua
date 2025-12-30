---@class trunks.StashLineData
---@field stash_index string

local M = {}

---@param bufnr integer
---@param line_num? integer
---@return { stash_index: string } | nil
local function get_line(bufnr, line_num)
    line_num = line_num or vim.api.nvim_win_get_cursor(0)[1]
    local line = vim.api.nvim_buf_get_lines(bufnr, line_num - 1, line_num, false)[1]
    if line == "" then
        return nil
    end
    return { stash_index = line:match(".+}") }
end

---@param bufnr integer
local function set_keymaps(bufnr)
    local keymaps = require("trunks._ui.keymaps.base").get_keymaps(bufnr, "stash", { auto_display_keymaps = true })
    local keymap_opts = { noremap = true, silent = true, buffer = bufnr, nowait = true }
    local set = require("trunks._ui.keymaps.set").safe_set_keymap

    set("n", keymaps.apply, function()
        local ok, line_data = pcall(get_line, bufnr)
        if not ok or not line_data then
            return
        end
        vim.cmd("G stash apply " .. line_data.stash_index)
    end, keymap_opts)

    set("n", keymaps.drop, function()
        local ok, line_data = pcall(get_line, bufnr)
        if not ok or not line_data then
            return
        end
        if
            require("trunks._ui.utils.confirm").confirm_choice(
                "Are you sure you want to drop " .. line_data.stash_index .. "?"
            )
        then
            vim.cmd("G stash drop " .. line_data.stash_index)
        end
    end, keymap_opts)

    set("n", keymaps.pop, function()
        local ok, line_data = pcall(get_line, bufnr)
        if not ok or not line_data then
            return
        end
        vim.cmd("G stash pop " .. line_data.stash_index)
    end, keymap_opts)

    set("n", keymaps.show, function()
        local ok, line_data = pcall(get_line, bufnr)
        if not ok or not line_data then
            return
        end
        require("trunks._ui.commit_details").render(line_data.stash_index, { is_stash = true })
    end, keymap_opts)
end

---@param bufnr integer
---@param opts trunks.UiRenderOpts
function M.render(bufnr, opts)
    local Command = require("trunks._core.command")
    local command_builder =
        Command.base_command("stash list --format='%C(yellow)%gd%C(reset) - %C(cyan)(%cr)%C(reset) %s%C(reset)'")

    local term = require("trunks._ui.elements").terminal(
        bufnr,
        command_builder:build(),
        { enter = true, display_strategy = "full", trigger_redraw = false, pty = true }
    )

    require("trunks._ui.auto_display").create_auto_display(bufnr, "stash", {
        generate_cmd = function()
            local ok, line_data = pcall(get_line, bufnr)
            if not ok or not line_data then
                return
            end
            local diff_command_builder = require("trunks._core.command").base_command(
                "stash show -p --include-untracked " .. line_data.stash_index
            )
            return diff_command_builder:build()
        end,
        get_current_diff = function()
            local ok, line_data = pcall(get_line, bufnr)
            if not ok or not line_data then
                return
            end
            return line_data.stash_index
        end,
        strategy = { display_strategy = "below", insert = false, trigger_redraw = false, pty = false },
    })

    set_keymaps(bufnr)
    if opts.set_keymaps then
        opts.set_keymaps(bufnr)
    end

    require("trunks._core.autocmds").execute_user_autocmds({ ui_type = "buffer", ui_name = "stash" })
    return bufnr, term.win
end

return M
