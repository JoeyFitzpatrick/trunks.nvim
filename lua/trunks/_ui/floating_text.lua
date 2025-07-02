local M = {}

---@param bufnr integer
---@param win integer
---@param text string
local function render_floating_win(bufnr, win, text)
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

---@param bufnr integer
---@param win integer
---@param text string
---@return integer
local function show_bottom_floating_text(bufnr, win, text)
    local function attach_resize_handler(float_win, row)
        local augroup = vim.api.nvim_create_augroup("BottomFloatingText_" .. float_win, { clear = false })
        vim.api.nvim_create_autocmd("WinResized", {
            group = augroup,
            callback = function()
                if not vim.api.nvim_win_is_valid(win) then
                    return
                end
                local new_row = vim.api.nvim_win_get_height(win) - 1
                local win_valid = vim.api.nvim_win_is_valid(float_win)
                if win_valid and new_row ~= row then
                    vim.api.nvim_win_close(float_win, true)
                end
                if (not win_valid) and new_row == row and vim.api.nvim_buf_is_valid(bufnr) then
                    local new_float_win = render_floating_win(bufnr, win, text)
                    attach_resize_handler(new_float_win, new_row)
                end
            end,
            desc = "Resize/move bottom floating text on window resize",
        })
    end

    local row = vim.api.nvim_win_get_height(win) - 1
    local float_win = render_floating_win(bufnr, win, text)
    attach_resize_handler(float_win, row)
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
