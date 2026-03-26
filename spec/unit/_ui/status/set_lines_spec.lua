local set_lines = require("trunks._ui.home_options.status")._set_lines

describe("status set_lines", function()
    it("displays basic information", function()
        local function generate_files()
            return {}
        end
        local bufnr = vim.api.nvim_create_buf(false, true)
        set_lines(bufnr, {
            get_files = generate_files,
            diff_stat_text = "No staged changes",
            remote_branch_text = "Rebase: origin/main",
        })
        local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

        assert.are.same({
            "Head: main",
            "Rebase: origin/main",
            "Help: g?",
            "No staged changes",
        }, lines)
    end)

    it("displays staged and unstaged files", function()
        local function generate_files()
            return {
                "A  added1",
                "A  added2",
                "M  modstage1",
                "M  modstage2",
                " M modunstage1",
                " M modunstage2",
                "?? untrack1",
                "?? untrack2",
            }
        end
        local bufnr = vim.api.nvim_create_buf(false, true)
        set_lines(bufnr, {
            get_files = generate_files,
            diff_stat_text = "No staged changes",

            remote_branch_text = "Rebase: origin/main",
        })
        local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

        assert.are.same({
            "Head: main",
            "Rebase: origin/main",
            "Help: g?",
            "No staged changes",
            "",
            "Unstaged (4)",
            "M modunstage1",
            "M modunstage2",
            "? untrack1",
            "? untrack2",
            "",
            "Staged (4)",
            "A added1",
            "A added2",
            "M modstage1",
            "M modstage2",
        }, lines)
    end)

    it("doesn't display an empty unstaged files section", function()
        local function generate_files()
            return {
                "A  added1",
                "A  added2",
            }
        end
        local bufnr = vim.api.nvim_create_buf(false, true)
        set_lines(bufnr, {
            get_files = generate_files,
            diff_stat_text = "No staged changes",
            remote_branch_text = "Rebase: origin/main",
        })
        local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

        assert.are.same({
            "Head: main",
            "Rebase: origin/main",
            "Help: g?",
            "No staged changes",
            "",
            "Staged (2)",
            "A added1",
            "A added2",
        }, lines)
    end)

    it("doesn't display an empty staged files section", function()
        local function generate_files()
            return {
                " M mod",
                "?? untracked",
            }
        end
        local bufnr = vim.api.nvim_create_buf(false, true)
        set_lines(bufnr, {
            get_files = generate_files,
            diff_stat_text = "No staged changes",
            remote_branch_text = "Rebase: origin/main",
        })
        local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

        assert.are.same({
            "Head: main",
            "Rebase: origin/main",
            "Help: g?",
            "No staged changes",
            "",
            "Unstaged (2)",
            "M mod",
            "? untracked",
        }, lines)
    end)

    it("sets a buffer-local variable with files", function()
        local function generate_files()
            return {
                "A  added1",
                "A  added2",
                "M  modstage1",
                "M  modstage2",
                " M modunstage1",
                " M modunstage2",
                "?? untrack1",
                "?? untrack2",
            }
        end
        local bufnr = vim.api.nvim_create_buf(false, true)
        set_lines(bufnr, {
            get_files = generate_files,
            diff_stat_text = "No staged changes",
            remote_branch_text = "Rebase: origin/main",
        })

        local status_files_from_buf_variable = vim.b[bufnr].trunks_status_files
        local expected = {
            unstaged = {
                ["modunstage1"] = { status = "M", staged = false, expanded = false },
                ["modunstage2"] = { status = "M", staged = false, expanded = false },
                ["untrack1"] = { status = "?", staged = false, expanded = false },
                ["untrack2"] = { status = "?", staged = false, expanded = false },
            },
            staged = {
                ["added1"] = { status = "A", staged = true, expanded = false },
                ["added2"] = { status = "A", staged = true, expanded = false },
                ["modstage1"] = { status = "M", staged = true, expanded = false },
                ["modstage2"] = { status = "M", staged = true, expanded = false },
            },
        }

        assert.are.same(expected, status_files_from_buf_variable)
    end)
end)
