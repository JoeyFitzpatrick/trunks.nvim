local parse = require("trunks._core.parse_command").parse

describe("parse command", function()
    it("replaces 'git switch origin/some-branch' with 'git switch some-branch'", function()
        local expected = "switch some-branch"
        assert.are.equal(expected, parse({ args = "switch origin/some-branch" }))
    end)

    it("does not remove 'origin/' from switch command when option is given", function()
        local expected = "switch origin/some-branch --create"
        assert.are.equal(expected, parse({ args = expected }))
    end)
end)
