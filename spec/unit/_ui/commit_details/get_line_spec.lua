local get_line = require("trunks._ui.commit_details").get_line

describe("commit_details get_line", function()
    local bufnr = nil
    before_each(function()
        bufnr = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
            "commit ea8a7c50e380d5d6e09dd69562f73c6242e27401",
            "Author: Joey Fitzpatrick <josephfitzpatrick333@yahoo.com>",
            "Date:   Fri Jan 2 22:43:01 2026 -0600",
            "",
            "    feat: fix diff and show commands",
            "",
            " 4 files changed, 6 insertions(+), 397 deletions(-)",
            " lua/trunks/_constants/command_strategies.lua         |   4 +-",
            " lua/trunks/_ui/diff_syntax.lua                       | 240 ----------------------------------------",
            " lua/trunks/_ui/interceptors/standard_interceptor.lua |  38 +------",
            " lua/trunks/_ui/stream.lua                            | 121 --------------------",
        })
    end)

    it("gets text at a line", function()
        local result = get_line(bufnr, 8)
        assert.are.same(result.filename, "lua/trunks/_constants/command_strategies.lua")
    end)

    it("does not get text for non-filename lines", function()
        for i = 1, 7 do
            local result = get_line(bufnr, i)
            assert.is_nil(result)
        end
    end)
end)
