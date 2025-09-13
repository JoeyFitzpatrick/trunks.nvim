local only_has_options = require("trunks._core.texter").only_has_options
local Command = require("trunks._core.command")

describe("only_has_options", function()
    it("should return true when a command contains a given option", function()
        assert.are.equal(
            true,
            only_has_options(Command.base_command("git branch --delete"), { "git", "branch", "--delete" })
        )
    end)

    it("should return false when a command contains a non-given option", function()
        assert.are.equal(
            false,
            only_has_options(Command.base_command("git branch --move"), { "git", "branch", "--delete" })
        )
    end)

    it("should return true when a command contains some of the given options", function()
        assert.are.equal(true, only_has_options(Command.base_command("git branch"), { "git", "branch", "--delete" }))
    end)
end)
