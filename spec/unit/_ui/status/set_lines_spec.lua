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
            "",
            "Unstaged (0)",
            "",
            "Staged (0)",
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
end)
