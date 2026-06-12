local M = {}

---@param bufnr integer
---@param diff_bufnrs trunks.DiffBufnrs
function M.set_diff_keymaps(bufnr, diff_bufnrs)
    local keymaps = require("trunks._ui.keymaps.base").get_keymaps(bufnr, "trunks_diff", {})
    local keymap_opts = { silent = true, buffer = bufnr, nowait = true }
    local set = require("trunks._ui.keymaps.set").safe_set_keymap

    local ours_bufnr = diff_bufnrs.ours_bufnr
    local theirs_bufnr = diff_bufnrs.theirs_bufnr

    local function set_for_diff_bufnrs(mode, lhs, rhs)
        for _, diff_bufnr in ipairs({ ours_bufnr, theirs_bufnr }) do
            set(mode, lhs, rhs, { buffer = diff_bufnr, silent = true, nowait = true })
        end
    end

    set_for_diff_bufnrs("n", keymaps.diffput, function()
        vim.cmd(string.format("diffput %d | diffupdate", bufnr))
    end)

    set("n", keymaps.get_ours_hunk, function()
        vim.cmd(string.format("diffget %d | diffupdate", ours_bufnr))
    end, keymap_opts)

    set("n", keymaps.get_theirs_hunk, function()
        vim.cmd(string.format("diffget %d | diffupdate", theirs_bufnr))
    end, keymap_opts)

    set("n", keymaps.merge_get_all, function()
        require("trunks._ui.interceptors.mergetool").replace_conflict("all")
    end, keymap_opts)
    set("n", keymaps.merge_get_ours, function()
        require("trunks._ui.interceptors.mergetool").replace_conflict("ours")
    end, keymap_opts)

    set("n", keymaps.merge_get_theirs, function()
        require("trunks._ui.interceptors.mergetool").replace_conflict("theirs")
    end, keymap_opts)
end

return M
