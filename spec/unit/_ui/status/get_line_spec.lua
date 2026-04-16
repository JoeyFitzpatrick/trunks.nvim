local get_line = require("trunks._ui.home_options.status").get_line

local base_lines = {
    "Head: main",
    "Rebase: origin/main",
    "Help: g?",
    "2 files changed, 2 insertions(+)",
    "",
    "Unstaged (3)",
    "M lua/trunks/_ui/home_options/status/init.lua",
    "M lua/trunks/types.lua",
    "? spec/unit/_ui/status/get_line_spec.lua",
    "",
    "Staged (4)",
    "M lua/trunks/_constants/keymap_descriptions.lua",
    "M lua/trunks/_core/default_configuration.lua",
    "M lua/trunks/_ui/utils/ui_utils.lua",
    "@@ -32,16 +32,4 @@ function M.get_visual_selection()",
    "     return text[1]",
    "+end",
    " ",
    "-function M.get_start_line(bufnr)",
    "-    if vim.api.nvim_buf_is_valid(bufnr) then",
    "-        return vim.b[bufnr].trunks_start_line or 0",
    "-    end",
    "-end",
    "-",
    "-function M.set_start_line(bufnr, line_num)",
    "-    if vim.api.nvim_buf_is_valid(bufnr) then",
    "-        vim.b[bufnr].trunks_start_line = line_num",
    "-    end",
    "-end",
    "-",
    " return M",
    "M lua/trunks/types.lua",
}

describe("status get_line", function()
    it("gets the file under the cursor", function()
        local bufnr = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, base_lines)
        local line = get_line(bufnr, 7)
        assert.are.equal("lua/trunks/_ui/home_options/status/init.lua", line.filename)
        assert.are.equal("M", line.status)
        assert.are.equal(false, line.staged)
    end)

    it("returns nil if no file under cursor", function()
        local bufnr = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, base_lines)
        for i = 1, 6 do
            local line = get_line(bufnr, i)
            assert.is_nil(line)
        end
        local line = get_line(bufnr, 10)
        assert.is_nil(line)
    end)

    it("gets a staged file", function()
        local bufnr = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, base_lines)
        local line = get_line(bufnr, 13)
        assert.are.equal("lua/trunks/_core/default_configuration.lua", line.filename)
        assert.are.equal("M", line.status)
        assert.are.equal(true, line.staged)
    end)

    it("gets a file when cursor on inline diff", function()
        local bufnr = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, base_lines)
        for i = 15, 17 do
            local line = get_line(bufnr, i)
            assert.are.equal("lua/trunks/_ui/utils/ui_utils.lua", line.filename)
            assert.are.equal("M", line.status)
            assert.are.equal(true, line.staged)
        end
    end)
end)
