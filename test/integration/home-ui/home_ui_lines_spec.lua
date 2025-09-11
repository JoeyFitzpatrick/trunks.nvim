local jobopts = { rpc = true, width = 80, height = 24 }

describe("Status tab in home UI", function()
    local nvim -- Channel of the embedded Neovim process

    before_each(function()
        -- Start a new Neovim process
        nvim = vim.fn.jobstart({ "nvim", "--embed", "--headless" }, jobopts)
    end)

    after_each(function()
        -- Terminate the Neovim process
        vim.fn.jobstop(nvim)
    end)

    it("Opens the status tab", function()
        vim.fn.system("mkdir functional-test-run && cd functional-test-run")

        -- Change to the test directory in the embedded nvim
        vim.rpcrequest(nvim, "nvim_command", "cd functional-test-run")

        vim.fn.system("git init")
        vim.fn.system("touch test.txt")
        vim.fn.system("git add -A")
        vim.fn.system("git commit -m 'initial commit'")

        vim.rpcrequest(nvim, "nvim_command", "G")

        local lines = vim.rpcrequest(nvim, "nvim_buf_get_lines", 0, 0, -1, false)
        local expected = {
            "h/l Change UI | c Commit | S Stash | d Discard | g? Help",
            "",
            "  ┌────────┐  ┌────────┐  ┌───────┐  ┌───────┐",
            "  │ Status │  │ Branch │  │  Log  │  │ Stash │",
            "  └────────┘  └────────┘  └───────┘  └───────┘",
            "",
            "HEAD: main ↑1",
            "No files staged",
        }
        assert.are.same(expected, lines)

        vim.rpcrequest(nvim, "nvim_input", "l")
        vim.wait(100, function() end)
        lines = vim.rpcrequest(nvim, "nvim_buf_get_lines", 0, 0, -1, false)
        expected = {
            "h/l Change UI | s Switch | n New branch | <enter> Commits | rn Rename | d Delete | g? Help",
            "",
            "  ┌────────┐  ┌────────┐  ┌───────┐  ┌───────┐",
            "  │ Status │  │ Branch │  │  Log  │  │ Stash │",
            "  └────────┘  └────────┘  └───────┘  └───────┘",
            "",
            "* main ",
        }
        assert.are.same(expected, lines)

        finally(function()
            vim.fn.system("cd ..")
            vim.fn.system("rm -rf functional-test-run")
        end)
    end)
end)
