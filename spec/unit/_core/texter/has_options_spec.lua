local has_options = require("trunks._core.texter").has_options

describe("has_options", function()
    it("should return true when a command contains a given option", function()
        assert.are.equal(true, has_options("git branch --delete", { "--delete" }))
    end)

    it("should return false when a command does not contain a given option", function()
        assert.are.equal(false, has_options("git branch --copy", { "--delete" }))
    end)

    it("should return false when a command does not have options", function()
        assert.are.equal(false, has_options("git branch", { "--delete" }))
    end)

    it("should return true when a command has a single-dash option", function()
        assert.are.equal(true, has_options("git branch -D", { "--delete", "-D" }))
    end)

    it("should return false when a command has a single-dash option that isn't given", function()
        assert.are.equal(false, has_options("git branch -M", { "--delete", "-D" }))
    end)

    it("should return true when a command has a single-dash option in middle of command", function()
        assert.are.equal(true, has_options("git branch -D --some-other-option", { "--delete", "-D" }))
    end)

    it("should return true for two word commands with flags", function()
        assert.are.equal(true, has_options("git stash show -p", { "-p" }))
    end)

    it("should return false for for flags that partially match", function()
        assert.are.equal(false, has_options("git grep --no-pager", { "--no" }))
        assert.are.equal(false, has_options("git grep --no-pager", { "-n" }))
    end)

    it("should return true for for flags that partially match with an =", function()
        assert.are.equal(true, has_options("git log --format=short", { "--format" }))
    end)

    it("should return false for for filepath flags (-- somefile.txt)", function()
        assert.are.equal(false, has_options("git log -- somefile.txt", { "--format", "--pretty" }))
    end)
end)
