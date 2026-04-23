local harness = require("spec.integration.harness")

---@class trunks.SmokeTestExpected
---@field creates_window? boolean  A new split window is opened
---@field opens_tab? boolean       A new tab is opened
---@field buf_changed? boolean     The current buffer is replaced (full-screen commands)
---@field is_print? boolean        Output is printed to cmdline; no new window or buffer change

---@class trunks.SmokeTestScenario
---@field id string
---@field cmd string
---@field setup? fun()
---@field expected trunks.SmokeTestExpected

describe("G command smoke tests", function()
    local nvim, test_repo

    setup(function()
        nvim, test_repo = harness.setup_child_nvim()
        vim.fn.system("git commit -m 'initial commit' --allow-empty --no-verify")
        vim.rpcrequest(nvim, "nvim_command", "!printf 'line 1\\nline 2\\nline 3\\n' > test.txt")
        vim.fn.system("git add test.txt")
        vim.fn.system("git commit -m 'add test.txt' --no-verify")
        -- A second modification ensures both HEAD~1 and HEAD have test.txt,
        -- which is required for difftool to open both sides of the diff.
        vim.rpcrequest(nvim, "nvim_command", "!printf 'line 4\\n' >> test.txt")
        vim.fn.system("git add test.txt")
        vim.fn.system("git commit -m 'modify test.txt' --no-verify")
    end)

    teardown(function()
        vim.fn.jobstop(nvim)
        vim.api.nvim_set_current_dir("..")
        vim.fn.system({ "rm", "-rf", test_repo })
    end)

    local function reset_state()
        pcall(vim.rpcrequest, nvim, "nvim_command", "silent! 1tabnext")
        pcall(vim.rpcrequest, nvim, "nvim_command", "silent! tabonly")
        -- G blame opens a left split whose BufHidden autocmd accesses the right (file) window.
        -- Moving right first ensures that window is still valid when `only` triggers BufHidden.
        pcall(vim.rpcrequest, nvim, "nvim_command", "silent! wincmd l")
        pcall(vim.rpcrequest, nvim, "nvim_command", "silent! only")
        pcall(vim.rpcrequest, nvim, "nvim_command", "silent! cclose")
        pcall(vim.rpcrequest, nvim, "nvim_command", "enew")
        vim.rpcrequest(nvim, "nvim_command", "let v:errmsg = ''")
    end

    -- All commands from lua/trunks/_ui/interceptors/init.lua, plus popular git commands.
    -- mergetool is omitted because it requires an active merge conflict to be meaningful.
    ---@type trunks.SmokeTestScenario[]
    local scenarios = {
        -- Home UI (no subcommand)
        {
            id = "G opens home UI in new tab",
            cmd = "G",
            expected = { opens_tab = true },
        },
        -- Interceptor commands (lua/trunks/_ui/interceptors/init.lua)
        {
            id = "G log",
            cmd = "G log",
            expected = { buf_changed = true },
        },
        {
            id = "G branch",
            cmd = "G branch",
            expected = { creates_window = true },
        },
        {
            id = "G blame",
            cmd = "G blame",
            setup = function()
                vim.rpcrequest(nvim, "nvim_command", "edit test.txt")
            end,
            expected = { creates_window = true },
        },
        {
            id = "G diff",
            cmd = "G diff HEAD",
            expected = { buf_changed = true },
        },
        {
            id = "G show",
            cmd = "G show HEAD",
            expected = { buf_changed = true },
        },
        {
            id = "G reflog",
            cmd = "G reflog",
            expected = { buf_changed = true },
        },
        {
            id = "G grep",
            cmd = "G grep line",
            expected = { creates_window = true },
        },
        {
            id = "G help",
            cmd = "G help",
            expected = { buf_changed = true },
        },
        {
            id = "G difftool",
            cmd = "G difftool HEAD~1 HEAD",
            expected = { opens_tab = true },
        },
        -- Popular git commands handled as terminal buffers (no interceptor)
        {
            id = "G status",
            cmd = "G status",
            expected = { creates_window = true },
        },
        {
            id = "G stash list",
            cmd = "G stash list",
            expected = { creates_window = true },
        },
        {
            id = "G commit --allow-empty",
            cmd = "G commit --allow-empty -m 'smoke test'",
            expected = { creates_window = true },
        },
        {
            id = "G add . uses print strategy",
            cmd = "G add .",
            expected = { is_print = true },
        },
    }

    for _, s in ipairs(scenarios) do
        it(s.id, function()
            reset_state()

            if s.setup then
                s.setup()
            end

            local initial_buf = vim.rpcrequest(nvim, "nvim_get_current_buf")
            local initial_win_count = vim.rpcrequest(nvim, "nvim_eval", "winnr('$')")
            local initial_tab_count = vim.rpcrequest(nvim, "nvim_eval", "tabpagenr('$')")

            vim.rpcrequest(nvim, "nvim_command", s.cmd)
            vim.wait(500, function() end)

            local errmsg = vim.rpcrequest(nvim, "nvim_eval", "v:errmsg")
            assert.are.equal("", errmsg)

            if s.expected.opens_tab then
                local tab_count = vim.rpcrequest(nvim, "nvim_eval", "tabpagenr('$')")
                assert.is_true(tab_count > initial_tab_count)
            end

            if s.expected.creates_window then
                local win_count = vim.rpcrequest(nvim, "nvim_eval", "winnr('$')")
                assert.is_true(win_count > initial_win_count)
            end

            if s.expected.buf_changed then
                local current_buf = vim.rpcrequest(nvim, "nvim_get_current_buf")
                assert.are_not.equal(initial_buf, current_buf)
            end

            if s.expected.is_print then
                local win_count = vim.rpcrequest(nvim, "nvim_eval", "winnr('$')")
                local current_buf = vim.rpcrequest(nvim, "nvim_get_current_buf")
                assert.are.equal(initial_win_count, win_count)
                assert.are.equal(initial_buf, current_buf)
            end
        end)
    end
end)
