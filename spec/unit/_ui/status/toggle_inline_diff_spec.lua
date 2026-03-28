local toggle_inline_diff = require("trunks._ui.home_options.status.status_utils").toggle_inline_diff

describe("toggle_inline_diff", function()
    it("toggles a diff on", function()
        local start_lines = {
            "Head: main ↑1",
            "Rebase: origin/main",
            "Help: g?",
            "No staged changes",
            "",
            "Unstaged (3)",
            "M lua/trunks/_ui/home_options/status/init.lua",
            "M lua/trunks/_ui/home_options/status/status_utils.lua",
            "? spec/unit/_ui/status/toggle_inline_diff_spec.lua",
        }

        local expected_lines = {
            "Head: main ↑1",
            "Rebase: origin/main",
            "Help: g?",
            "No staged changes",
            "",
            "Unstaged (3)",
            "M lua/trunks/_ui/home_options/status/init.lua",
            "@@ -322,30 +322,6 @@ function M.set_keymaps(bufnr)",
            "     )",
            " end",
            " ",
            "----@param line_data trunks.StatusLineData",
            "----@return string",
            "-local function get_diff_cmd(line_data)",
            "-    local status = line_data.status",
            "-    local safe_filename = line_data.safe_filename",
            "-    local is_staged = line_data.staged",
            "-",
            '-    local is_untracked = status == "?"',
            "-    if is_untracked then",
            '-        return "diff --no-index /dev/null -- " .. safe_filename',
            "-    end",
            "-",
            "-    if is_staged then",
            '-        return "diff --staged -- " .. safe_filename',
            "-    end",
            "-",
            '-    local is_modified = status == "M"',
            "-    if is_modified then",
            '-        return "diff -- " .. safe_filename',
            "-    end",
            "-",
            '-    return "diff -- " .. safe_filename',
            "-end",
            "-",
            " ---@class trunks.StatusSetLinesContext",
            " ---@field get_files? fun(): string[]",
            " ---@field diff_stat_text? string",
            "@@ -437,7 +413,7 @@ function M.render(bufnr, opts)",
            "             if last_file ~= line_data.filename then",
            "                 vim.b[bufnr].trunks_last_file = line_data.filename",
            "             end",
            "-            return Command.base_command(get_diff_cmd(line_data)):build()",
            "+            return Command.base_command(status_utils.get_diff_cmd(line_data)):build()",
            "         end),",
            "         get_current_diff = with_line(bufnr, M.get_line, function(line_data)",
            "             return line_data.safe_filename",
            "M lua/trunks/_ui/home_options/status/status_utils.lua",
            "? spec/unit/_ui/status/toggle_inline_diff_spec.lua",
        }

        local bufnr = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, start_lines)
        vim.b[bufnr].trunks_status_files = {
            staged = {},
            unstaged = {
                ["lua/trunks/_ui/home_options/status/init.lua"] = {
                    expanded = false,
                    staged = false,
                    status = "M",
                },
                ["lua/trunks/_ui/home_options/status/status_utils.lua"] = {
                    expanded = false,
                    staged = false,
                    status = "M",
                },
                ["spec/unit/_ui/status/toggle_inline_diff_spec.lua"] = {
                    expanded = false,
                    staged = false,
                    status = "?",
                },
            },
        }

        local mock_diff = vim.list_slice(expected_lines, 8, 47)
        toggle_inline_diff(bufnr, 7, {
            filename = "lua/trunks/_ui/home_options/status/init.lua",
            safe_filename = "'lua/trunks/_ui/home_options/status/init.lua'",
            status = "M",
            staged = false,
        }, function(_)
            return mock_diff, 0
        end)
        assert.are.same(expected_lines, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false))
    end)

    it("toggles a diff off", function()
        local start_lines = {
            "Head: main ↑1",
            "Rebase: origin/main",
            "Help: g?",
            "No staged changes",
            "",
            "Unstaged (3)",
            "M lua/trunks/_ui/home_options/status/init.lua",
            "@@ -322,30 +322,6 @@ function M.set_keymaps(bufnr)",
            "     )",
            " end",
            " ",
            "----@param line_data trunks.StatusLineData",
            "----@return string",
            "-local function get_diff_cmd(line_data)",
            "-    local status = line_data.status",
            "-    local safe_filename = line_data.safe_filename",
            "-    local is_staged = line_data.staged",
            "-",
            '-    local is_untracked = status == "?"',
            "-    if is_untracked then",
            '-        return "diff --no-index /dev/null -- " .. safe_filename',
            "-    end",
            "-",
            "-    if is_staged then",
            '-        return "diff --staged -- " .. safe_filename',
            "-    end",
            "-",
            '-    local is_modified = status == "M"',
            "-    if is_modified then",
            '-        return "diff -- " .. safe_filename',
            "-    end",
            "-",
            '-    return "diff -- " .. safe_filename',
            "-end",
            "-",
            " ---@class trunks.StatusSetLinesContext",
            " ---@field get_files? fun(): string[]",
            " ---@field diff_stat_text? string",
            "@@ -437,7 +413,7 @@ function M.render(bufnr, opts)",
            "             if last_file ~= line_data.filename then",
            "                 vim.b[bufnr].trunks_last_file = line_data.filename",
            "             end",
            "-            return Command.base_command(get_diff_cmd(line_data)):build()",
            "+            return Command.base_command(status_utils.get_diff_cmd(line_data)):build()",
            "         end),",
            "         get_current_diff = with_line(bufnr, M.get_line, function(line_data)",
            "             return line_data.safe_filename",
            "M lua/trunks/_ui/home_options/status/status_utils.lua",
            "? spec/unit/_ui/status/toggle_inline_diff_spec.lua",
        }

        local expected_lines = {
            "Head: main ↑1",
            "Rebase: origin/main",
            "Help: g?",
            "No staged changes",
            "",
            "Unstaged (3)",
            "M lua/trunks/_ui/home_options/status/init.lua",
            "M lua/trunks/_ui/home_options/status/status_utils.lua",
            "? spec/unit/_ui/status/toggle_inline_diff_spec.lua",
        }

        -- Test toggling off from:
        -- line 7: line with filename
        -- line 8: first diff line (starts with @@)
        -- line 9: first non-@@ line
        -- line 47: last line of diff
        local line_nums_to_test = { 7, 8, 9, 47 }
        for _, line_num in ipairs(line_nums_to_test) do
            local bufnr = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, start_lines)
            vim.b[bufnr].trunks_status_files = {
                staged = {},
                unstaged = {
                    ["lua/trunks/_ui/home_options/status/init.lua"] = {
                        expanded = true,
                        staged = false,
                        status = "M",
                    },
                    ["lua/trunks/_ui/home_options/status/status_utils.lua"] = {
                        expanded = false,
                        staged = false,
                        status = "M",
                    },
                    ["spec/unit/_ui/status/toggle_inline_diff_spec.lua"] = {
                        expanded = false,
                        staged = false,
                        status = "?",
                    },
                },
            }

            toggle_inline_diff(bufnr, line_num, {
                filename = "lua/trunks/_ui/home_options/status/init.lua",
                safe_filename = "'lua/trunks/_ui/home_options/status/init.lua'",
                status = "M",
                staged = false,
            })
            assert.are.same(expected_lines, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false))
        end
    end)

    it("toggles a diff on for an untracked file", function()
        local start_lines = {
            "Head: main ↑1",
            "Rebase: origin/main",
            "Help: g?",
            "No staged changes",
            "",
            "Unstaged (1)",
            "? spec/unit/_ui/status/toggle_inline_diff_spec.lua",
        }

        local expected_lines = {
            "Head: main ↑1",
            "Rebase: origin/main",
            "Help: g?",
            "No staged changes",
            "",
            "Unstaged (1)",
            "? spec/unit/_ui/status/toggle_inline_diff_spec.lua",
            "@@ -322,30 +322,6 @@ function M.set_keymaps(bufnr)",
            "     )",
            " end",
            " ",
            "----@param line_data trunks.StatusLineData",
            "----@return string",
            "-local function get_diff_cmd(line_data)",
            "-    local status = line_data.status",
            "-    local safe_filename = line_data.safe_filename",
            "-    local is_staged = line_data.staged",
            "-",
            '-    local is_untracked = status == "?"',
            "-    if is_untracked then",
            '-        return "diff --no-index /dev/null -- " .. safe_filename',
            "-    end",
            "-",
            "-    if is_staged then",
            '-        return "diff --staged -- " .. safe_filename',
            "-    end",
            "-",
            '-    local is_modified = status == "M"',
            "-    if is_modified then",
            '-        return "diff -- " .. safe_filename',
            "-    end",
            "-",
            '-    return "diff -- " .. safe_filename',
            "-end",
            "-",
            " ---@class trunks.StatusSetLinesContext",
            " ---@field get_files? fun(): string[]",
            " ---@field diff_stat_text? string",
            "@@ -437,7 +413,7 @@ function M.render(bufnr, opts)",
            "             if last_file ~= line_data.filename then",
            "                 vim.b[bufnr].trunks_last_file = line_data.filename",
            "             end",
            "-            return Command.base_command(get_diff_cmd(line_data)):build()",
            "+            return Command.base_command(status_utils.get_diff_cmd(line_data)):build()",
            "         end),",
            "         get_current_diff = with_line(bufnr, M.get_line, function(line_data)",
            "             return line_data.safe_filename",
        }

        local bufnr = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, start_lines)
        vim.b[bufnr].trunks_status_files = {
            staged = {},
            unstaged = {
                ["spec/unit/_ui/status/toggle_inline_diff_spec.lua"] = {
                    expanded = false,
                    staged = false,
                    status = "?",
                },
            },
        }

        local mock_diff = vim.list_slice(expected_lines, 8, 47)
        toggle_inline_diff(bufnr, 7, {
            filename = "spec/unit/_ui/status/toggle_inline_diff_spec.lua",
            safe_filename = "'spec/unit/_ui/status/toggle_inline_diff_spec.lua'",
            status = "?",
            staged = false,
        }, function(_)
            return mock_diff, 0
        end)
        assert.are.same(expected_lines, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false))
    end)
end)
