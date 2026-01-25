local bufnr = vim.api.nvim_create_buf(false, true)
local win = vim.api.nvim_get_current_win()
vim.api.nvim_open_term(bufnr, {})
vim.api.nvim_win_set_buf(win, bufnr)
vim.print(vim.o.number)

vim.keymap.set("n", "x", function()
    vim.api.nvim_open_term(bufnr, {})
end, { buffer = bufnr })
