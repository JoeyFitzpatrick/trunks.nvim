local test_repo = "test-repo"
local jobopts = { rpc = true, width = 80, height = 24 }

describe("Status tab in home UI", function()
    vim.fn.system({ "mkdir", test_repo })
    vim.fn.system({ "git", "init", test_repo })
    vim.api.nvim_set_current_dir(test_repo)
    local nvim = vim.fn.jobstart({ "nvim", "--embed", "--headless" }, jobopts)

    it("Opens the status tab", function()
        finally(function()
            vim.fn.jobstop(nvim)
            vim.api.nvim_set_current_dir("..")
            vim.fn.system({ "rm", "-rf", test_repo })
        end)

        vim.rpcrequest(nvim, "nvim_command", "!touch test.txt")
        vim.fn.system("git add test.txt")
        vim.fn.system("git commit -m 'initial commit' --no-verify")
        vim.rpcrequest(nvim, "nvim_command", "G")

        local lines = vim.rpcrequest(nvim, "nvim_buf_get_lines", 0, 0, -1, false)

        -- Status UI
        local expected = {
            "h/l Change UI | c Commit | S Stash | d Discard | g? Help",
            "",
            "  ┌────────┐  ┌────────┐  ┌───────┐  ┌───────┐",
            "  │ Status │  │ Branch │  │  Log  │  │ Stash │",
            "  └────────┘  └────────┘  └───────┘  └───────┘",
            "",
            "HEAD: main ",
            "No files staged",
        }
        assert.are.same(expected, lines)

        vim.rpcrequest(nvim, "nvim_input", "l")

        -- Branch UI
        lines = vim.rpcrequest(nvim, "nvim_buf_get_lines", 0, 0, -1, false)
        expected = {
            "h/l Change UI | s Switch | n New branch | <enter> Commits | rn Rename | d Delete | g? Help",
            "",
            "  ┌────────┐  ┌────────┐  ┌───────┐  ┌───────┐",
            "  │ Status │  │ Branch │  │  Log  │  │ Stash │",
            "  └────────┘  └────────┘  └───────┘  └───────┘",
            "",
            "* main",
        }
        assert.are.same(expected, lines)

        vim.rpcrequest(nvim, "nvim_input", "l")

        -- Log UI
        vim.wait(300, function() end) -- This UI streams in content, wait for it to come in
        -- Commit can change, so only check static lines for exact match
        lines = vim.rpcrequest(nvim, "nvim_buf_get_lines", 0, 0, 7, false)
        expected = {
            "h/l Change UI | <enter> Details | rb Rebase | rv Revert | c Checkout | d Diff | g? Help",
            "",
            "  ┌────────┐  ┌────────┐  ┌───────┐  ┌───────┐",
            "  │ Status │  │ Branch │  │  Log  │  │ Stash │",
            "  └────────┘  └────────┘  └───────┘  └───────┘",
            "",
            "HEAD: main",
        }
        assert.are.same(expected, lines)

        local commit_line = vim.rpcrequest(nvim, "nvim_buf_get_lines", 0, -2, -1, false)[1]
        assert.is_not_nil(commit_line:match("^%x+"))
        assert.is_not_nil(commit_line:find("initial commit", 1, true))

        -- Stash UI
        vim.rpcrequest(nvim, "nvim_command", "!touch stash.txt")
        vim.fn.system("git add stash.txt")
        vim.fn.system("git stash")
        vim.rpcrequest(nvim, "nvim_input", "l")

        -- Stash timing can change, so only check static lines for exact match
        lines = vim.rpcrequest(nvim, "nvim_buf_get_lines", 0, 0, 6, false)
        expected = {
            "h/l Change UI | a Apply | p Pop | d Drop | <enter> Details | g? Help",
            "",
            "  ┌────────┐  ┌────────┐  ┌───────┐  ┌───────┐",
            "  │ Status │  │ Branch │  │  Log  │  │ Stash │",
            "  └────────┘  └────────┘  └───────┘  └───────┘",
            "",
            -- "stash@{0}    2 seconds ago        On main: test            ",
        }
        assert.are.same(expected, lines)

        local stash_line = vim.rpcrequest(nvim, "nvim_buf_get_lines", 0, -2, -1, false)[1]
        assert.is_not_nil(stash_line:find("stash@{0}", 0, true))
    end)
end)
