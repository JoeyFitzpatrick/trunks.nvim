-- vim.cmd("tabnew")
-- local buf = vim.api.nvim_create_buf(false, true)
-- vim.api.nvim_win_set_buf(0, buf)
-- local ns_id = vim.api.nvim_create_namespace("trunks_home_header")
--
-- vim.api.nvim_buf_set_extmark(buf, ns_id, 0, 0, {
--     virt_lines = {
--         { "hello", "Comment" },
--     },
--     virt_lines_above = true,
-- })

local api = vim.api

local bnr = vim.fn.bufnr("%")
local ns_id = api.nvim_create_namespace("demo")
api.nvim_open_term(bnr, {})

local line_num = 5
local col_num = 5

local opts = {
    virt_text = { { "demo", "IncSearch" } },
    virt_lines_above = true,
}

local mark_id = api.nvim_buf_set_extmark(bnr, ns_id, 0, 0, opts)
