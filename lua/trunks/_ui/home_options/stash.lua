--Stash ui

---@class trunks.StashLineData
---@field stash_index string

local M = {}

--- Highlight stash lines
---@param bufnr integer
---@param start_line integer
---@param lines string[]
local function highlight(bufnr, start_line, lines)
    local highlight_line = require("trunks._ui.highlight").highlight_line
    for i, line in ipairs(lines) do
        if line == "" then
            return
        end
        local line_num = i + start_line - 1
        local stash_index_start, stash_index_end = line:find("^%S+")
        highlight_line(bufnr, "Keyword", line_num, stash_index_start, stash_index_end)
        local date_start, date_end = line:find(".+ago", stash_index_end + 1)
        highlight_line(bufnr, "Function", line_num, date_start, date_end)
        local branch_start, branch_end = line:find(" .+:", date_end + 1)
        highlight_line(bufnr, "Removed", line_num, branch_start, branch_end)
    end
end

---@param bufnr integer
---@param opts trunks.UiRenderOpts
---@return string[]
local function set_lines(bufnr, opts)
    require("trunks._ui.keymaps.keymaps_text").show(bufnr, opts.ui_types)
    local start_line = opts.start_line or 2
    local output =
        require("trunks._core.run_cmd").run_cmd("stash list --pretty=format:'%<(12)%gd %<(18)%cr   %<(25)%s'")
    vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
    vim.api.nvim_buf_set_lines(bufnr, start_line, -1, false, output)
    vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
    highlight(bufnr, start_line, output)
    return output
end

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
    -- If there's already a buffer named TrunksStash, just don't set a name
    pcall(vim.api.nvim_buf_set_name, bufnr, "TrunksStash")

    set_lines(bufnr, opts)
    require("trunks._ui.auto_display").create_auto_display(bufnr, "stash", {
        generate_cmd = function()
            local ok, line_data = pcall(get_line, bufnr)
            if not ok or not line_data then
                return
            end
            local command_builder = require("trunks._core.command").base_command(
                "stash show -p --include-untracked " .. line_data.stash_index
            )
            return command_builder:build()
        end,
        get_current_diff = function()
            local ok, line_data = pcall(get_line, bufnr)
            if not ok or not line_data then
                return
            end
            return line_data.stash_index
        end,
        strategy = { display_strategy = "right", insert = false, trigger_redraw = false },
    })

    set_keymaps(bufnr)
end

return M
