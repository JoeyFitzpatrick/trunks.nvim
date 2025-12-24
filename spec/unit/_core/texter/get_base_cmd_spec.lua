local get_base_cmd = require("trunks._core.texter").get_base_cmd

describe("get_base_cmd", function()
    it("should get the base command for a simple git command", function()
        assert.are.equal("status", get_base_cmd("git status"))
    end)

    it("should get the base command when the git prefix is omitted", function()
        assert.are.equal("status", get_base_cmd("status"))
    end)

    it("should get the base command for command with a prefix arg", function()
        assert.are.equal("status", get_base_cmd("git --no-pager status"))
        assert.are.equal("status", get_base_cmd("git --no-pager -a status"))
    end)

    it("should get the base command for command with a postfix args", function()
        assert.are.equal("status", get_base_cmd("git status -s --short"))
    end)
end)
