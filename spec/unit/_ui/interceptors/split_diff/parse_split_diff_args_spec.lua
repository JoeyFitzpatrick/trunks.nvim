local parse_split_diff_args = require("trunks._ui.interceptors.split_diff")._parse_split_diff_args

describe("parse_split_diff_args", function()
    before_each(function()
        vim.fn.expand = function()
            return "%"
        end
    end)

    it("should parse args when no commit is given", function()
        local expected =
            { filepath = "%", left_commit = require("trunks._constants.constants").WORKING_TREE, right_commit = "HEAD" }
        assert.are.same(expected, parse_split_diff_args("vdiff"))
        -- The input string should never be empty, but testing anyways
        assert.are.same(expected, parse_split_diff_args(""))
    end)

    it("should parse args when a commit is given", function()
        local commit = "abc123"
        local expected =
            { filepath = "%", left_commit = require("trunks._constants.constants").WORKING_TREE, right_commit = commit }
        assert.are.same(expected, parse_split_diff_args("vdiff " .. commit))
    end)

    it("should parse args when a branch is given", function()
        local branch = "me/some-branch-here"
        local expected =
            { filepath = "%", left_commit = require("trunks._constants.constants").WORKING_TREE, right_commit = branch }
        assert.are.same(expected, parse_split_diff_args("vdiff " .. branch))
    end)

    it("should use both commits when two are given", function()
        local branches = "me/some-branch me/other-branch"
        local expected = { filepath = "%", left_commit = "me/some-branch", right_commit = "me/other-branch" }
        assert.are.same(expected, parse_split_diff_args("vdiff " .. branches))
    end)

    it("should use both commits when range is given", function()
        local branches = "me/some-branch..me/other-branch"
        local expected = { filepath = "%", left_commit = "me/some-branch", right_commit = "me/other-branch" }
        assert.are.same(expected, parse_split_diff_args("vdiff " .. branches))
    end)
end)
