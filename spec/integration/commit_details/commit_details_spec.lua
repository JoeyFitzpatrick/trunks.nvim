local harness = require("spec.integration.harness")
describe("Commit details", function()
    local nvim, test_repo = harness.setup_child_nvim()
    it("displays commit details and opens a file in a split", function()
        finally(function()
            vim.fn.jobstop(nvim)
            vim.api.nvim_set_current_dir("..")
            vim.fn.system({ "rm", "-rf", test_repo })
        end)

        -- Make an initial commit
        vim.fn.system("git commit -m 'initial commit' --no-verify --allow-empty")

        -- Make a commit with a file
        vim.rpcrequest(nvim, "nvim_command", "!echo 'line 1' >> test.txt")
        vim.rpcrequest(nvim, "nvim_command", "!echo 'line 2' >> test.txt")
        vim.fn.system("git add test.txt")
        vim.fn.system("git commit -m 'add file' --no-verify")

        vim.rpcrequest(nvim, "nvim_command", "G log")

        -- Wait for log to stream in
        vim.wait(1000, function()
            local lines = vim.rpcrequest(nvim, "nvim_buf_get_lines", 0, 0, -1, false)
            vim.tbl_contains(lines, function(val)
                return val:find("add file", 1, true)
            end)
        end)

        -- Move cursor down to commit hash and select it
        vim.rpcrequest(nvim, "nvim_input", "j")
        vim.rpcrequest(nvim, "nvim_input", "<enter>")

        -- We should now be in commit details
        local commit_details_first_lines = vim.rpcrequest(nvim, "nvim_buf_get_lines", 0, 0, 3, false)
        assert.is_not_nil(commit_details_first_lines[1]:match("commit %x+"))
        assert.is_not_nil(commit_details_first_lines[2]:match("Author: %S+"))
        assert.is_not_nil(commit_details_first_lines[3]:match("Date:%s+%S+"))

        local commit_details_content_lines = vim.rpcrequest(nvim, "nvim_buf_get_lines", 0, 4, -1, false)

        local expected_lines = {
            "    add file",
            "",
            " 1 file changed, 2 insertions(+)",
            " test.txt | 2 ++",
        }

        assert.are.same(expected_lines, commit_details_content_lines)

        -- Assert cursor is on the changed file
        local current_line = vim.rpcrequest(nvim, "nvim_get_current_line")
        assert.are.equal(current_line, " test.txt | 2 ++")

        -- Open file in vertical split with "ov" keymap
        vim.rpcrequest(nvim, "nvim_input", "ov")
        local lines = vim.rpcrequest(nvim, "nvim_buf_get_lines", 0, 0, -1, false)
        assert.are.same(lines, { "line 1", "line 2" })

        -- Assert buffer name is commit_hash--filename
        local buffer_name = vim.rpcrequest(nvim, "nvim_buf_get_name", 0)
        assert.is_not_nil(buffer_name:match("%x+%-%-test.txt"))

        -- Assert buffer is not editable
        local is_modifiable = vim.rpcrequest(nvim, "nvim_get_option_value", "modifiable", {})
        assert.is_false(is_modifiable)
    end)
end)
