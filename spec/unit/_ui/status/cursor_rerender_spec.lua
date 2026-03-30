local status_module = require("trunks._ui.home_options.status")

local base_lines = {
    "Head: main",
    "Rebase: origin/main",
    "Help: g?",
    "2 files changed, 2 insertions(+)",
    "",
    "Unstaged (2)",
    "M lua/trunks/_ui/home_options/status/init.lua",
    "? spec/unit/_ui/status/get_line_spec.lua",
    "",
    "Staged (2)",
    "M lua/trunks/_constants/keymap_descriptions.lua",
    "M lua/trunks/_core/default_configuration.lua",
}

describe("status buffer cursor behavior on rerender", function()
    it("fetches state", function()
        local bufnr = vim.api.nvim_create_buf(false, true)
        local win = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(win, bufnr)
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, base_lines)
        vim.api.nvim_win_set_cursor(win, { 7, 0 })
        local cursor_state = status_module._get_cursor_state(bufnr, win)
        assert.are.same({
            cursor = { 7, 0 },
            line = "M lua/trunks/_ui/home_options/status/init.lua",
            section = "Unstaged",
            section_header_line = 6,
            line_data = {
                filename = "lua/trunks/_ui/home_options/status/init.lua",
                safe_filename = "'lua/trunks/_ui/home_options/status/init.lua'",
                status = "M",
                staged = false,
            },
        }, cursor_state)
    end)

    local rerender_scenarios = {
        {
            id = "sets cursor to first file in other section when current section closes",
            start_line = 11,
            expected_line = 7,
            new_lines = {
                "Head: main",
                "Rebase: origin/main",
                "Help: g?",
                "2 files changed, 2 insertions(+)",
                "",
                "Unstaged (2)",
                "M lua/trunks/_ui/home_options/status/init.lua",
                "? spec/unit/_ui/status/get_line_spec.lua",
            },
        },
        {
            id = "moves cursor to next file when first file in section is removed",
            start_line = 11,
            expected_line = 12,
            new_lines = {
                "Head: main",
                "Rebase: origin/main",
                "Help: g?",
                "2 files changed, 2 insertions(+)",
                "",
                "Unstaged (3)",
                "M lua/trunks/_ui/home_options/status/init.lua",
                "? spec/unit/_ui/status/get_line_spec.lua",
                "M lua/trunks/_constants/keymap_descriptions.lua",
                "",
                "Staged (1)",
                "M lua/trunks/_core/default_configuration.lua",
            },
        },
        {
            id = "keeps cursor on current line if all sections removed",
            start_line = 1,
            expected_line = 1,
            new_lines = {
                "Head: main",
                "Rebase: origin/main",
                "Help: g?",
                "No staged changes",
            },
        },
        {
            id = "keeps cursor on bottom line if all sections removed and current line is too low",
            start_line = 11,
            expected_line = 4,
            new_lines = {
                "Head: main",
                "Rebase: origin/main",
                "Help: g?",
                "No staged changes",
            },
        },
        {
            id = "keeps cursor in current section if new section appears",
            start_line = 7,
            expected_line = 10,
            start_lines = {
                "Head: main",
                "Rebase: origin/main",
                "Help: g?",
                "2 files changed, 2 insertions(+)",
                "",
                "Staged (4)",
                "M lua/trunks/_ui/home_options/status/init.lua",
                "? spec/unit/_ui/status/get_line_spec.lua",
                "M lua/trunks/_constants/keymap_descriptions.lua",
                "M lua/trunks/_core/default_configuration.lua",
            },
            new_lines = {
                "Head: main",
                "Rebase: origin/main",
                "Help: g?",
                "2 files changed, 2 insertions(+)",
                "",
                "Unstaged (1)",
                "M lua/trunks/_ui/home_options/status/init.lua",
                "",
                "Staged (3)",
                "? spec/unit/_ui/status/get_line_spec.lua",
                "M lua/trunks/_constants/keymap_descriptions.lua",
                "M lua/trunks/_core/default_configuration.lua",
            },
        },
        {
            id = "moves cursor to first line in section that replaces current section",
            start_line = 8,
            expected_line = 7,
            start_lines = {
                "Head: main",
                "Rebase: origin/main",
                "Help: g?",
                "2 files changed, 2 insertions(+)",
                "",
                "Unstaged (4)",
                "M lua/trunks/_ui/home_options/status/init.lua",
                "? spec/unit/_ui/status/get_line_spec.lua",
                "M lua/trunks/_constants/keymap_descriptions.lua",
                "M lua/trunks/_core/default_configuration.lua",
            },
            new_lines = {
                "Head: main",
                "Rebase: origin/main",
                "Help: g?",
                "2 files changed, 2 insertions(+)",
                "",
                "Staged (4)",
                "M lua/trunks/_ui/home_options/status/init.lua",
                "? spec/unit/_ui/status/get_line_spec.lua",
                "M lua/trunks/_constants/keymap_descriptions.lua",
                "M lua/trunks/_core/default_configuration.lua",
            },
        },
    }

    for _, scenario in ipairs(rerender_scenarios) do
        it(scenario.id, function()
            local bufnr = vim.api.nvim_create_buf(false, true)
            local win = vim.api.nvim_get_current_win()
            vim.api.nvim_win_set_buf(win, bufnr)
            vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, scenario.start_lines or base_lines)
            vim.api.nvim_win_set_cursor(win, { scenario.start_line, 0 })
            local cursor_state = status_module._get_cursor_state(bufnr, win)

            local new_lines = scenario.new_lines

            vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, new_lines)
            local new_cursor_pos = status_module._set_cursor(bufnr, win, cursor_state)
            assert.are.same({ scenario.expected_line, 0 }, new_cursor_pos)
        end)
    end
end)
