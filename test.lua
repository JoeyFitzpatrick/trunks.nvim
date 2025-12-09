vim.cmd("tabnew")
local status = "git --no-pager status -s"
local log = "git --no-pager log --pretty='%C(yellow)%h %Cblue%>(12)%ad %Cgreen%<(7)%aN%Cred%d %Creset%s'"
local branch = "git --no-pager branch"
local diff = "git --no-pager diff | delta --paging=never"

local function render_term(cmd)
    local buf = vim.api.nvim_create_buf(false, true)
    local chan = vim.api.nvim_open_term(buf, {})
    vim.fn.jobstart(cmd, {
        pty = true,
        on_stdout = function(_, data, _)
            for _, line in ipairs(data) do
                if line ~= "" then
                    vim.api.nvim_chan_send(chan, line .. "\r\n")
                end
            end
        end,
        on_exit = function()
            vim.defer_fn(function()
                vim.api.nvim_win_set_buf(0, buf)
            end, 10)
        end,
    })

    vim.keymap.set("n", "s", function()
        vim.system({ "git", "stage", "--all" }):wait()
        render_term(status)
    end)

    vim.keymap.set("n", "u", function()
        vim.system({ "git", "reset" }):wait()
        render_term(status)
    end)
end

render_term(status)
