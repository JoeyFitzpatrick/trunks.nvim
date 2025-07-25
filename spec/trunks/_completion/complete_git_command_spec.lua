local complete_git_command = require("trunks._completion.completion").complete_git_command

describe("complete_git_command", function()
    before_each(function()
        require("trunks._completion.completion").get_branches = function()
            return { "branch_completion" }
        end

        require("trunks._completion.completion")._path_completion = function()
            return { "path_completion" }
        end
    end)

    it("should display command options for regular commands", function()
        local result = complete_git_command("commit ", "G commit ")
        assert.are.equal(true, vim.tbl_contains(result, "--no-verify"))
    end)

    it("should display command options when arglead begins with '-' ", function()
        local result = complete_git_command("-", "G switch -")
        assert.are.equal(true, vim.tbl_contains(result, "--create"))
    end)

    it("should display branch completion for some commands", function()
        local result = complete_git_command("switch ", "G switch ")
        assert.are.equal(true, vim.tbl_contains(result, "branch_completion"))
    end)

    it("should display filepath completion for some commands", function()
        local result = complete_git_command("add ", "G add ")
        assert.are.equal(true, vim.tbl_contains(result, "path_completion"))
    end)

    it("should display subcommand completion for some commands", function()
        local result = complete_git_command("stash ", "G stash ")
        assert.are.equal(true, vim.tbl_contains(result, "push"))
    end)
end)
