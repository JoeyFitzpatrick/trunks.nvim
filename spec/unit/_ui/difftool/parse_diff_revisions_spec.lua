local parse_diff_revisions = require("trunks._ui.interceptors.difftool")._parse_diff_revisions

describe("parse_diff_revisions", function()
    local scenarios = {
        { id = "with no args", input = "difftool", expected = { "HEAD", nil } },
        { id = "with no args and whitespace", input = "difftool  ", expected = { "HEAD", nil } },
        { id = "with no args and whitespace", input = "difftool  ", expected = { "HEAD", nil } },
        { id = "with a branch", input = "difftool some-branch", expected = { nil, "some-branch" } },
        { id = "with a commit hash", input = "difftool abc123", expected = { nil, "abc123" } },
        { id = "with a two commits", input = "difftool abc123 def456", expected = { "abc123", "def456" } },
    }
    for _, scenario in ipairs(scenarios) do
        it("parses a difftool command " .. scenario.id, function()
            local left_commit, right_commit = parse_diff_revisions(scenario.input)
            assert.are.same(scenario.expected, { left_commit, right_commit })
        end)
    end
end)
