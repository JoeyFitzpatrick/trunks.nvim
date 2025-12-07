vim.cmd("tabnew")
local buf = vim.api.nvim_create_buf(false, true)
-- vim.api.nvim_buf_set_lines(buf, 0, 1, false, { "parent" })
local chan = vim.api.nvim_open_term(buf, {})
local status = "git --no-pager status -s"
local log = "git --no-pager log --pretty='%C(yellow)%h %Cblue%>(12)%ad %Cgreen%<(7)%aN%Cred%d %Creset%s'"
local branch = "git --no-pager branch"
local diff = "git --no-pager diff | delta --paging=never"

vim.fn.jobstart(diff, {
    pty = false,
    on_stdout = function(_, data, _)
        for _, line in ipairs(data) do
            if line ~= "" then
                vim.api.nvim_chan_send(chan, line .. "\r\n")
            end
        end
    end,
})
vim.api.nvim_win_set_buf(0, buf)

vim.keymap.set("n", "q", function()
    vim.api.nvim_buf_delete(buf, { force = true })
end, { buffer = buf })
