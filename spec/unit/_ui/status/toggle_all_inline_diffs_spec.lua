local status_utils = require("trunks._ui.home_options.status.status_utils")
local toggle_all_inline_diffs = status_utils.toggle_all_inline_diffs

local function make_diff(filename)
    return {
        "@@ -1,3 +1,3 @@",
        "-old line for " .. filename,
        "+new line for " .. filename,
        " context line",
    }
end

describe("toggle_all_inline_diffs", function()
    it("expands every collapsed file in a section", function()
        local start_lines = {
            "Head: main",
            "Rebase: origin/main",
            "Help: g?",
            "No staged changes",
            "",
            "Unstaged (2)",
            "M file_a.lua",
            "M file_b.lua",
        }

        local bufnr = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, start_lines)
        vim.b[bufnr].trunks_status_files = {
            staged = {},
            unstaged = {
                ["file_a.lua"] = { expanded = false, staged = false, status = "M" },
                ["file_b.lua"] = { expanded = false, staged = false, status = "M" },
            },
        }

        toggle_all_inline_diffs(bufnr, "unstaged", function(cmd)
            local filename = cmd:match("file_%a")
            return make_diff(filename), 0
        end)

        local expected_lines = {
            "Head: main",
            "Rebase: origin/main",
            "Help: g?",
            "No staged changes",
            "",
            "Unstaged (2)",
            "M file_a.lua",
            "@@ -1,3 +1,3 @@",
            "-old line for file_a",
            "+new line for file_a",
            " context line",
            "M file_b.lua",
            "@@ -1,3 +1,3 @@",
            "-old line for file_b",
            "+new line for file_b",
            " context line",
        }
        assert.are.same(expected_lines, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false))

        local status_files = vim.b[bufnr].trunks_status_files
        assert.is_true(status_files.unstaged["file_a.lua"].expanded)
        assert.is_true(status_files.unstaged["file_b.lua"].expanded)
    end)

    it("expands a section even if some files are already expanded", function()
        local start_lines = {
            "Head: main",
            "Rebase: origin/main",
            "Help: g?",
            "No staged changes",
            "",
            "Unstaged (2)",
            "M file_a.lua",
            "@@ -1,3 +1,3 @@",
            "-old line for file_a",
            "+new line for file_a",
            " context line",
            "M file_b.lua",
        }

        local bufnr = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, start_lines)
        vim.b[bufnr].trunks_status_files = {
            staged = {},
            unstaged = {
                ["file_a.lua"] = { expanded = true, staged = false, status = "M" },
                ["file_b.lua"] = { expanded = false, staged = false, status = "M" },
            },
        }

        toggle_all_inline_diffs(bufnr, "unstaged", function(cmd)
            local filename = cmd:match("file_%a")
            return make_diff(filename), 0
        end)

        local status_files = vim.b[bufnr].trunks_status_files
        assert.is_true(status_files.unstaged["file_a.lua"].expanded)
        assert.is_true(status_files.unstaged["file_b.lua"].expanded)
    end)

    it("collapses every file in a section when all are expanded", function()
        local start_lines = {
            "Head: main",
            "Rebase: origin/main",
            "Help: g?",
            "No staged changes",
            "",
            "Unstaged (2)",
            "M file_a.lua",
            "@@ -1,3 +1,3 @@",
            "-old line for file_a",
            "+new line for file_a",
            " context line",
            "M file_b.lua",
            "@@ -1,3 +1,3 @@",
            "-old line for file_b",
            "+new line for file_b",
            " context line",
        }

        local bufnr = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, start_lines)
        vim.b[bufnr].trunks_status_files = {
            staged = {},
            unstaged = {
                ["file_a.lua"] = { expanded = true, staged = false, status = "M" },
                ["file_b.lua"] = { expanded = true, staged = false, status = "M" },
            },
        }

        toggle_all_inline_diffs(bufnr, "unstaged", function()
            error("run_cmd_fn should not be called when collapsing")
        end)

        local expected_lines = {
            "Head: main",
            "Rebase: origin/main",
            "Help: g?",
            "No staged changes",
            "",
            "Unstaged (2)",
            "M file_a.lua",
            "M file_b.lua",
        }
        assert.are.same(expected_lines, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false))

        local status_files = vim.b[bufnr].trunks_status_files
        assert.is_false(status_files.unstaged["file_a.lua"].expanded)
        assert.is_false(status_files.unstaged["file_b.lua"].expanded)
    end)

    it("leaves the other section's expanded diffs intact", function()
        local start_lines = {
            "Head: main",
            "Rebase: origin/main",
            "Help: g?",
            "No staged changes",
            "",
            "Unstaged (1)",
            "M file_a.lua",
            "",
            "Staged (1)",
            "M file_b.lua",
            "@@ -1,3 +1,3 @@",
            "-old line for file_b",
            "+new line for file_b",
            " context line",
        }

        local bufnr = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, start_lines)
        vim.b[bufnr].trunks_status_files = {
            staged = {
                ["file_b.lua"] = { expanded = true, staged = true, status = "M" },
            },
            unstaged = {
                ["file_a.lua"] = { expanded = false, staged = false, status = "M" },
            },
        }

        toggle_all_inline_diffs(bufnr, "unstaged", function(cmd)
            local filename = cmd:match("file_%a")
            return make_diff(filename), 0
        end)

        local expected_lines = {
            "Head: main",
            "Rebase: origin/main",
            "Help: g?",
            "No staged changes",
            "",
            "Unstaged (1)",
            "M file_a.lua",
            "@@ -1,3 +1,3 @@",
            "-old line for file_a",
            "+new line for file_a",
            " context line",
            "",
            "Staged (1)",
            "M file_b.lua",
            "@@ -1,3 +1,3 @@",
            "-old line for file_b",
            "+new line for file_b",
            " context line",
        }
        assert.are.same(expected_lines, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false))
    end)
end)
