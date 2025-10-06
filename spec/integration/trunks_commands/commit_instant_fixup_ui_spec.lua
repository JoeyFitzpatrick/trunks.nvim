local harness = require("spec.integration.harness")
describe("Commit instant fixup UI", function()
    local nvim, test_repo = harness.setup_child_nvim()
    it("Allows a commit to be fixed up", function()
        finally(function()
            vim.fn.jobstop(nvim)
            vim.api.nvim_set_current_dir("..")
            vim.fn.system({ "rm", "-rf", test_repo })
        end)

        -- Make an initial commit
        vim.fn.system("git commit -m 'initial commit' --no-verify --allow-empty")

        -- Make a commit with a file
        vim.rpcrequest(nvim, "nvim_command", "!touch test.txt")
        vim.fn.system("git add test.txt")
        vim.fn.system("git commit -m 'add file' --no-verify")

        -- Stage a second file
        vim.rpcrequest(nvim, "nvim_command", "!touch test2.txt")
        vim.fn.system("git add test2.txt")

        local initial_buffer = vim.rpcrequest(nvim, "nvim_get_current_buf")

        vim.rpcrequest(nvim, "nvim_command", "Trunks commit-instant-fixup")

        local raw_buffer_name = vim.rpcrequest(nvim, "nvim_buf_get_name", 0)
        local buffer_name = vim.fn.fnamemodify(raw_buffer_name, ":~:.")

        -- Assert in log UI
        assert.are.same("TrunksCommitInstantFixupChoose", buffer_name)

        -- Pressing enter on the first line should no-op since it isn't a commit
        vim.rpcrequest(nvim, "nvim_input", "<enter>")

        -- Wait for log to stream in
        vim.wait(1000, function()
            local lines = vim.rpcrequest(nvim, "nvim_buf_get_lines", 0, 0, -1, false)
            vim.tbl_contains(lines, function(val)
                return val:find("add file", 1, true)
            end)
        end)

        assert.are.equal(raw_buffer_name, vim.rpcrequest(nvim, "nvim_buf_get_name", 0))

        -- Move cursor down to commit hash and select it
        vim.rpcrequest(nvim, "nvim_input", "j")
        vim.rpcrequest(nvim, "nvim_input", "<enter>")

        vim.wait(1000, function()
            -- Wait for log UI to close
            return vim.rpcrequest(nvim, "nvim_get_current_buf") == initial_buffer
        end)

        local changed_files = vim.fn.systemlist("git diff-tree --no-commit-id --name-only HEAD")
        assert.is_true(vim.tbl_contains(changed_files, "test.txt"))
        assert.is_true(vim.tbl_contains(changed_files, "test2.txt"))
    end)
end)
