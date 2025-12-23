vim.cmd("tabnew")
local status = "git --no-pager status -s"
local log = "git --no-pager log --pretty='%C(yellow)%h %Cblue%>(12)%ad %Cgreen%<(7)%aN%Cred%d %Creset%s'"
local branch = "git --no-pager branch"
local diff = "git --no-pager diff | delta --paging=never"
local commit = "git commit"

local buf = vim.api.nvim_create_buf(false, true)
local chan = vim.api.nvim_open_term(buf, {})
vim.api.nvim_win_set_buf(0, buf)

local esc = string.char(27)
vim.api.nvim_chan_send(chan, "first")
vim.api.nvim_chan_send(chan, esc .. "[H") -- go home
vim.api.nvim_chan_send(chan, "second")
