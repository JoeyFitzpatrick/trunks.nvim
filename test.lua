local bufnr = vim.api.nvim_create_buf(false, true)
local win = vim.api.nvim_get_current_win()
vim.api.nvim_win_set_buf(win, bufnr)

require("trunks._ui.home_options.status")._set_lines(bufnr)
require("trunks._ui.home_options.status").set_keymaps(bufnr)
