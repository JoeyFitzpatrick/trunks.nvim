local buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(buf, 0, 1, false, { "parent" })
vim.api.nvim_win_set_buf(0, buf)

local new_buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(new_buf, 0, 1, false, { "child" })
local split = vim.api.nvim_open_win(new_buf, false, { split = "above", height = 5 })

vim.api.nvim_create_autocmd("BufLeave", {
    buffer = buf,
    desc = "Remove home UI info when parent buffer is hidden",
    callback = function()
        if vim.api.nvim_buf_is_valid(new_buf) then
            vim.api.nvim_buf_delete(new_buf, { force = true })
        end
    end,
})

vim.keymap.set("n", "q", function()
    vim.api.nvim_buf_delete(buf, { force = true })
end, { buffer = buf })
