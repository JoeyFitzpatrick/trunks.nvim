vim.cmd("tabnew")
local status = "git --no-pager status -s"
local log = "git --no-pager log --pretty='%C(yellow)%h %Cblue%>(12)%ad %Cgreen%<(7)%aN%Cred%d %Creset%s'"
local branch = "git --no-pager branch"
local diff = "git --no-pager diff | delta --paging=never"
local commit = "git commit"

local buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_win_set_buf(0, buf)
vim.wo.number = true

local chan = nil

local function render_term(cmd)
    if not chan then
        chan = vim.api.nvim_open_term(buf, {})
    end
    local esc = string.char(27)
    vim.api.nvim_chan_send(chan, esc .. "[H") -- go home
    local is_streaming = false
    vim.fn.jobstart(cmd, {
        term = true,
        on_stdout = function(_, data, _)
            for _, line in ipairs(data) do
                if line ~= "" then
                    if is_streaming then
                        -- line = "\r\n" .. line
                    end
                    vim.api.nvim_chan_send(chan, line)
                end
            end
            is_streaming = true
        end,
        on_exit = function()
            -- vim.api.nvim_chan_send(chan, esc .. "[E") -- go down one line
            -- vim.api.nvim_chan_send(chan, esc .. "[J") -- clear screen from cursor
        end,
    })
end
vim.keymap.set("n", "s", function()
    vim.system({ "git", "stage", "--all" }):wait()
    render_term(status)
end, { buffer = buf })

vim.keymap.set("n", "u", function()
    vim.system({ "git", "reset" }):wait()
    render_term(status)
end, { buffer = buf })

render_term(commit)
