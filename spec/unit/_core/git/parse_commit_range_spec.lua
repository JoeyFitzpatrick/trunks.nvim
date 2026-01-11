local parse_commit_range = require("trunks._core.git").parse_commit_range

describe("parse commit range", function()
    local params = {
        { desc = "working_tree, HEAD for an empty commit range", { left = "working_tree", right = "HEAD" }, nil },
        { desc = "working_tree, HEAD for an empty string", { left = "working_tree", right = "HEAD" }, "" },
        { desc = "working_tree, abc123 for a single commit", { left = "working_tree", right = "abc123" }, "abc123" },
        { desc = "working_tree, HEAD~10 for commit index", { left = "working_tree", right = "HEAD~10" }, "HEAD~10" },
        { desc = "left, right for a commit range", { left = "abc123", right = "def456" }, "abc123..def456" },
        { desc = "left, right for a spaced commit range", { left = "abc123", right = "def456" }, "abc123 def456" },
        { desc = "left, HEAD for commit range with empty right", { left = "abc123", right = "HEAD" }, "abc123.." },
        { desc = "HEAD, right for commit range with empty left", { left = "HEAD", right = "abc123" }, "..abc123" },
    }

    for _, param in ipairs(params) do
        it("returns " .. param.desc, function()
            assert.are.same(param[1], parse_commit_range(param[2]))
        end)
    end
end)
