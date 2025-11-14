local harness = require("spec.integration.harness")

describe("Register and q keymap", function()
    local nvim, test_repo = harness.setup_child_nvim()

    it("handles q keymap across multiple buffers correctly", function()
        finally(function()
            vim.fn.jobstop(nvim)
            vim.api.nvim_set_current_dir("..")
            vim.fn.system({ "rm", "-rf", test_repo })
        end)

        vim.fn.system("git commit -m 'initial commit' --no-verify --allow-empty")

        vim.rpcrequest(nvim, "nvim_command", "!echo 'line 1' >> test.txt")
        vim.rpcrequest(nvim, "nvim_command", "!echo 'line 2' >> test.txt")
        vim.fn.system("git add test.txt")
        vim.fn.system("git commit -m 'add file' --no-verify")

        vim.rpcrequest(nvim, "nvim_command", "G")

        vim.rpcrequest(nvim, "nvim_input", "l")
        vim.rpcrequest(nvim, "nvim_input", "l")

        vim.wait(1000, function()
            local lines = vim.rpcrequest(nvim, "nvim_buf_get_lines", 0, 0, -1, false)
            for _, line in ipairs(lines) do
                if line:find("add file", 1, true) then
                    return true
                end
            end
            return false
        end)

        vim.rpcrequest(nvim, "nvim_input", "j")
        vim.rpcrequest(nvim, "nvim_input", "<enter>")

        vim.wait(100)

        local commit_details_bufnr = vim.rpcrequest(nvim, "nvim_get_current_buf")
        local commit_details_first_lines = vim.rpcrequest(nvim, "nvim_buf_get_lines", 0, 0, 3, false)
        assert.is_not_nil(commit_details_first_lines[1]:match("commit %x+"))

        local current_line = vim.rpcrequest(nvim, "nvim_get_current_line")
        assert.are.equal(current_line, " test.txt | 2 ++")

        vim.rpcrequest(nvim, "nvim_input", "ov")

        local file_split_bufnr = vim.rpcrequest(nvim, "nvim_get_current_buf")
        local lines = vim.rpcrequest(nvim, "nvim_buf_get_lines", 0, 0, -1, false)
        assert.are.same(lines, { "line 1", "line 2" })

        local buffer_name = vim.rpcrequest(nvim, "nvim_buf_get_name", 0)
        assert.is_not_nil(buffer_name:match("%x+%-%-test.txt"))

        vim.rpcrequest(nvim, "nvim_input", "q")

        vim.wait(100)

        local current_buf_after_q = vim.rpcrequest(nvim, "nvim_get_current_buf")
        assert.are.equal(current_buf_after_q, commit_details_bufnr)

        local buf_valid = vim.rpcrequest(nvim, "nvim_buf_is_valid", file_split_bufnr)
        assert.is_false(buf_valid)

        vim.rpcrequest(nvim, "nvim_input", "ov")

        local file_split_bufnr_2 = vim.rpcrequest(nvim, "nvim_get_current_buf")
        local lines_2 = vim.rpcrequest(nvim, "nvim_buf_get_lines", 0, 0, -1, false)
        assert.are.same(lines_2, { "line 1", "line 2" })

        local win_count = vim.rpcrequest(nvim, "nvim_eval", "winnr('$')")
        assert.are.equal(win_count, 2)

        vim.rpcrequest(nvim, "nvim_command", "wincmd h")

        local current_buf_before_second_q = vim.rpcrequest(nvim, "nvim_get_current_buf")
        assert.are.equal(current_buf_before_second_q, commit_details_bufnr)

        vim.rpcrequest(nvim, "nvim_input", "q")

        local current_buf_after_second_q = vim.rpcrequest(nvim, "nvim_get_current_buf")
        assert.are.equal(current_buf_after_second_q, file_split_bufnr_2)

        local commit_details_buf_valid = vim.rpcrequest(nvim, "nvim_buf_is_valid", commit_details_bufnr)
        assert.is_false(commit_details_buf_valid)

        vim.rpcrequest(nvim, "nvim_input", "q")

        local file_split_buf_valid = vim.rpcrequest(nvim, "nvim_buf_is_valid", file_split_bufnr_2)
        assert.is_false(file_split_buf_valid)

        local win_count_final = vim.rpcrequest(nvim, "nvim_eval", "winnr('$')")
        assert.are.equal(win_count_final, 1)

        local register_buffers =
            vim.rpcrequest(nvim, "nvim_exec_lua", "return require('trunks._core.register').buffers", {})
        local buffer_count = 0
        for _ in pairs(register_buffers) do
            buffer_count = buffer_count + 1
        end
        assert.are.equal(buffer_count, 0)
    end)
end)
