local set_lines = require("trunks._ui.home_options.status")._set_lines

describe("status set_lines", function()
    it("displays basic information", function()
        local function generate_files()
            return {}
        end
        local bufnr = vim.api.nvim_create_buf(false, true)
        set_lines(bufnr, { get_files = generate_files, diff_stat_text = "No staged changes" })
        local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

        local head_line = lines[1]
        assert.are.same("Head: main", head_line)

        local help_line = lines[2]
        assert.are.same(help_line, "Help: g?")
        assert.are.same("Help: g?", help_line)

        local diff_stat_line = lines[3]
        assert.are.same("No staged changes", diff_stat_line)

        local unstaged_changes_line = lines[5]
        assert.are.same("Unstaged (0)", unstaged_changes_line)

        local staged_changes_line = lines[7]
        assert.are.same("Staged (0)", staged_changes_line)
    end)

    it("displays number of staged and unstaged files", function()
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
        set_lines(bufnr, { get_files = generate_files, diff_stat_text = "No staged changes" })
        local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

        local unstaged_changes_line = lines[5]
        assert.are.same("Unstaged (4)", unstaged_changes_line)

        local staged_changes_line = lines[7]
        assert.are.same("Staged (4)", staged_changes_line)
    end)
end)
