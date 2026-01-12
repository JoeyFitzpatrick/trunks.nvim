local M = {}

---@param bufnr integer
---@param line_num? integer
---@return { hash: string } | nil
local function get_line(bufnr, line_num)
    line_num = line_num or vim.api.nvim_win_get_cursor(0)[1]
    local line = vim.api.nvim_buf_get_lines(bufnr, line_num - 1, line_num, false)[1]
    if line == "" then
        return nil
    end
    return { hash = line:match("%w+") }
end

---@param bufnr integer
local function set_keymaps(bufnr)
    local keymaps = require("trunks._ui.keymaps.base").get_keymaps(bufnr, "reflog", {})
    local keymap_opts = { noremap = true, silent = true, buffer = bufnr, nowait = true }
    local set = require("trunks._ui.keymaps.set").safe_set_keymap

    set("n", keymaps.checkout, function()
        local ok, line_data = pcall(get_line, bufnr)
        if not ok or not line_data then
            return
        end
        vim.cmd("G checkout " .. line_data.hash)
    end, keymap_opts)

    set("n", keymaps.commit_details, function()
        local ok, line_data = pcall(get_line, bufnr)
        if not ok or not line_data then
            return
        end
        require("trunks._ui.commit_details").render(line_data.hash, {})
    end, keymap_opts)

    set("n", keymaps.recover, function()
        local ok, line_data = pcall(get_line, bufnr)
        if not ok or not line_data then
            return
        end
        vim.ui.input({ prompt = "Name for new branch off of " .. line_data.hash .. ": " }, function(input)
            if not input then
                return
            end
            vim.cmd(string.format("G checkout -b %s %s", input, line_data.hash))
        end)
    end, keymap_opts)

    set("n", keymaps.show, require("trunks._ui.keymaps.base").git_show_keymap_fn(bufnr, get_line), keymap_opts)
end

---@param command_builder trunks.Command
function M.render(command_builder)
    local bufnr = require("trunks._ui.elements").new_buffer({ buffer_name = os.tmpname() .. "TrunksReflog" })
    require("trunks._ui.elements").terminal(bufnr, command_builder:build())
    set_keymaps(bufnr)
    require("trunks._ui.keymaps.keymaps_text").show_in_cmdline(bufnr, { "reflog" })

    require("trunks._core.autocmds").execute_user_autocmds({ ui_type = "buffer", ui_name = "reflog" })
end

return M
