local harness = require("spec.integration.harness")

describe("Git blame", function()
    local nvim, test_repo = harness.setup_child_nvim()

    it("reblames correctly across file renames", function()
        finally(function()
            vim.fn.jobstop(nvim)
            vim.api.nvim_set_current_dir("..")
            vim.fn.system({ "rm", "-rf", test_repo })
        end)

        vim.fn.system("git commit -m 'initial commit' --no-verify --allow-empty")

        vim.rpcrequest(nvim, "nvim_command", "!echo 'line 1' > original.txt")
        vim.rpcrequest(nvim, "nvim_command", "!echo 'line 2' >> original.txt")
        vim.fn.system("git add original.txt")
        local commit1_hash = vim.fn.system("git commit -m 'add original file' --no-verify"):match("%x%x%x%x%x%x%x")

        vim.rpcrequest(nvim, "nvim_command", "!echo 'line 3' >> original.txt")
        vim.fn.system("git add original.txt")
        vim.fn.system("git commit -m 'add line 3' --no-verify"):match("%x%x%x%x%x%x%x")

        vim.fn.system("git mv original.txt renamed.txt")
        vim.fn.system("git commit -m 'rename file' --no-verify")

        vim.rpcrequest(nvim, "nvim_command", "!echo 'line 4' >> renamed.txt")
        vim.fn.system("git add renamed.txt")
        vim.fn.system("git commit -m 'add line 4' --no-verify")

        vim.rpcrequest(nvim, "nvim_command", "edit renamed.txt")
        vim.rpcrequest(nvim, "nvim_command", "G blame -C")

        vim.wait(1000, function()
            local lines = vim.rpcrequest(nvim, "nvim_buf_get_lines", 0, 0, -1, false)
            return #lines >= 4
        end)

        local blame_lines = vim.rpcrequest(nvim, "nvim_buf_get_lines", 0, 0, -1, false)
        assert.are.equal(4, #blame_lines)
        assert.is_not_nil(blame_lines[3]:match("TrunksFilename:original%.txt"))

        vim.rpcrequest(nvim, "nvim_win_set_cursor", 0, { 3, 0 })
        vim.rpcrequest(nvim, "nvim_input", "r")

        vim.wait(1000, function()
            local buffer_name = vim.rpcrequest(nvim, "nvim_buf_get_name", 0)
            return buffer_name:match("TrunksBlame://")
        end)

        local reblame1_lines = vim.rpcrequest(nvim, "nvim_buf_get_lines", 0, 0, -1, false)
        assert.are.equal(3, #reblame1_lines)
        assert.is_not_nil(reblame1_lines[1]:match(commit1_hash))

        vim.rpcrequest(nvim, "nvim_win_set_cursor", 0, { 2, 0 })
        vim.rpcrequest(nvim, "nvim_input", "r")

        vim.wait(1000, function()
            local lines = vim.rpcrequest(nvim, "nvim_buf_get_lines", 0, 0, -1, false)
            return #lines == 2
        end)

        local reblame2_lines = vim.rpcrequest(nvim, "nvim_buf_get_lines", 0, 0, -1, false)
        assert.are.equal(2, #reblame2_lines)
        assert.is_not_nil(reblame2_lines[1]:match(commit1_hash))
    end)
end)
