local render_auto_display = require("trunks._ui.auto_display")._render_auto_display

local default_opts = {
    generate_cmd = function()
        return "cmd"
    end,
    get_current_diff = function()
        return "diff"
    end,
    strategy = {},
}

describe("render_auto_display", function()
    it("should set buffer state", function()
        local bufnr = vim.api.nvim_create_buf(false, true)
        render_auto_display(bufnr, default_opts)
        local state = vim.b[bufnr].trunks_auto_display_state
        assert.are.same("diff", state.current_diff)
        assert.are.same(true, state.show_auto_display)
        assert.are_not.same(nil, state.diff_bufnr)
    end)
end)
