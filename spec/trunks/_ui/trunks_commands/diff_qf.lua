describe("diff-qf diff line parser", function()
    local parse_diff_line = require("trunks._ui.trunks_commands.diff_qf")._parse_diff_line
    it("returns a file location in a git diff output line", function()
        local result = parse_diff_line({
            "diff --git c/README.md w/README.md",
            "index ce51519..24439ed 100644",
            "--- c/README.md",
            "+++ w/README.md",
            "@@ -102,6 +102,7 @@ Note: lazy loading is handled internally, so it is not required to lazy load Tru",
            ' commit_amend_reuse_message = "A",',
            ' commit_dry_run = "d",',
            ' commit_no_verify = "n",',
            '+                    commit_instant_fixup = "F", -- Run :Trunks commit-instant-fixup',
            " },",
            " },",
            " diff = {",
        })

        local expected = { filename = "README.md", line_nums = { 105 } }
        assert.are.same(expected, result)
    end)

    it("returns a multiple file locations in a git diff output line", function()
        local result = parse_diff_line({
            "diff --git c/README.md w/README.md",
            "index ce51519..24439ed 100644",
            "--- c/README.md",
            "+++ w/README.md",
            "@@ -102,6 +102,7 @@ Note: lazy loading is handled internally, so it is not required to lazy load Tru",
            ' commit_amend_reuse_message = "A",',
            ' commit_dry_run = "d",',
            ' commit_no_verify = "n",',
            '+                    commit_instant_fixup = "F", -- Run :Trunks commit-instant-fixup',
            " },",
            "+},", -- This is a new added line
            " diff = {",
        })

        local expected = { filename = "README.md", line_nums = { 105, 107 } }
        assert.are.same(expected, result)
    end)

    it("returns a single file location for a group of connected changes", function()
        local result = parse_diff_line({
            "diff --git c/README.md w/README.md",
            "index ce51519..24439ed 100644",
            "--- c/README.md",
            "+++ w/README.md",
            "@@ -102,6 +102,7 @@ Note: lazy loading is handled internally, so it is not required to lazy load Tru",
            ' commit_amend_reuse_message = "A",',
            ' commit_dry_run = "d",',
            ' commit_no_verify = "n",',
            -- These 3 lines have no unchanges lines between them, so they count as a single group
            '+                    commit_instant_fixup = "F", -- Run :Trunks commit-instant-fixup',
            "+},",
            "+},",
            " diff = {",
        })

        local expected = { filename = "README.md", line_nums = { 105 } }
        assert.are.same(expected, result)
    end)
end)
