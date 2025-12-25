local cmd_contains_options = require("trunks._constants.command_strategies")._cmd_contains_options

describe("cmd_contains_options", function()
    it("should return true if a cmd contains a given option", function()
        local cmd = { "git", "branch", "--list" }
        assert.are.equal(true, cmd_contains_options(cmd, { "--list" }))
        assert.are.equal(true, cmd_contains_options(cmd, { "--all", "--list" }))
    end)

    it("should return false if a cmd does not contain a given option", function()
        local cmd = { "git", "branch", "--list" }
        assert.are.equal(false, cmd_contains_options(cmd, { "--all" }))
    end)

    it("should return true if a cmd contains a part that starts with a given option", function()
        local cmd = { "git", "branch", "--sort=-HEAD" }
        assert.are.equal(true, cmd_contains_options(cmd, { "--sort" }))
    end)
end)
