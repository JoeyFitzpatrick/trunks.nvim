vim.cmd("tabnew")
local status = "git --no-pager status -s"
local log = "git --no-pager log --pretty='%C(yellow)%h %Cblue%>(12)%ad %Cgreen%<(7)%aN%Cred%d %Creset%s'"
local branch = "git --no-pager branch"
local diff = "git --no-pager diff | delta --paging=never"

local buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_win_set_buf(0, buf)
vim.wo.number = false

local chan = nil

local function render_term(cmd)
    if not chan then
        chan = vim.api.nvim_open_term(buf, {})
    end
    local esc = string.char(27)
    -- vim.api.nvim_chan_send(chan, esc .. "[H") -- go home
    -- vim.api.nvim_chan_send(chan, esc .. "[J") -- clear screen
    local lines = {}
    vim.fn.jobstart(cmd, {
        pty = true,
        on_stdout = function(_, data, _)
            for _, line in ipairs(data) do
                if line ~= "" then
                    table.insert(lines, line)
                end
            end
        end,
        on_exit = function()
            vim.bo.modifiable = true
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
            vim.api.nvim_open_term(buf, {})
            vim.wait(10, function() end)
            -- vim.api.nvim_win_set_buf(0, buf)

            vim.keymap.set("n", "s", function()
                vim.system({ "git", "stage", "--all" }):wait()
                render_term(status)
            end, { buffer = buf })

            vim.keymap.set("n", "u", function()
                vim.system({ "git", "reset" }):wait()
                render_term(status)
            end, { buffer = buf })
        end,
    })
end

render_term(status)
