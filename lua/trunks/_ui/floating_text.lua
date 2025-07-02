local M = {}

local function show_bottom_floating_text(bufnr, win, text)
    local width = vim.api.nvim_win_get_width(win)
    local height = 1
    local row = vim.api.nvim_win_get_height(win) - 1
    local col = 0

    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { text })

    local float_win = vim.api.nvim_open_win(buf, false, {
        relative = "win",
        win = win,
        width = width,
        height = height,
        row = row,
        col = col,
        focusable = false,
        style = "minimal",
        border = "none",
        noautocmd = true,
    })

    vim.api.nvim_win_set_option(float_win, "winhl", "Normal:Function")

    -- Autocmd to close floating window when bufnr or win closes
    local augroup = vim.api.nvim_create_augroup("BottomFloatingText_" .. float_win, { clear = true })
    vim.api.nvim_create_autocmd({ "BufWipeout", "WinClosed" }, {
        group = augroup,
        buffer = bufnr,
        callback = function()
            if vim.api.nvim_win_is_valid(float_win) then
                vim.api.nvim_win_close(float_win, true)
            end
        end,
        desc = "Close bottom floating text when buffer or window closes",
    })
    return float_win
end

function M.set_bottom_text(bufnr, win, text)
    show_bottom_floating_text(bufnr, win, text)
end

---@param bufnr integer
---@param win integer
---@param ui_types string[]
function M.show_keymaps(bufnr, win, ui_types)
    local keymaps_string = require("trunks._constants.keymap_descriptions").get_short_descriptions_as_string(ui_types)
    M.set_bottom_text(bufnr, win, keymaps_string)
end

return M
