local M = {}

local function highlight(bufnr)
    for i, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 2, -1, false)) do
        i = i + 2
        local hash_start, hash_end = line:find("%x+")
        require("trunks._ui.highlight").highlight_line(bufnr, "Identifier", i - 1, hash_start, hash_end)
        if not hash_start or not hash_end then
            return
        end
        local ref_start, ref_end = line:find(".+}", hash_end + 1)
        require("trunks._ui.highlight").highlight_line(bufnr, "Keyword", i - 1, ref_start, ref_end)
    end
end

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
    local bufnr = require("trunks._ui.elements").new_buffer({
        buffer_name = os.tmpname() .. "TrunksReflog",
        filetype = "git",
    })
    require("trunks._ui.keymaps.keymaps_text").show(bufnr, { "reflog" })
    local output = require("trunks._core.run_cmd").run_cmd(command_builder)
    require("trunks._ui.utils.buffer_text").set(bufnr, output, 2)
    highlight(bufnr)
    set_keymaps(bufnr)
end

return M
