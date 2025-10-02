local complete_git_command = require("trunks._completion.completion").complete_command

describe("complete_git_command", function()
    before_each(function()
        require("trunks._completion.completion").get_branches = function()
            return { "branch_completion" }
        end

        require("trunks._completion.completion")._path_completion = function()
            return { "path_completion" }
        end
    end)

    it("should display commands when first command isn't completed", function()
        local result = complete_git_command("co", "co", "G")
        assert.are.equal(true, vim.tbl_contains(result, "commit"))
    end)

    it("should display command options when arglead begins with '-' ", function()
        local result = complete_git_command("-", "G switch -", "G")
        assert.are.equal(true, vim.tbl_contains(result, "--create="))
    end)

    it("should display branch completion for some commands", function()
        local result = complete_git_command("switch ", "G switch ", "G")
        assert.are.equal(true, vim.tbl_contains(result, "branch_completion"))
    end)

    it("should display filepath completion for some commands", function()
        local result = complete_git_command("add ", "G add ", "G")
        assert.are.equal(true, vim.tbl_contains(result, "path_completion"))
    end)

    it("should display subcommand completion for some commands", function()
        local result = complete_git_command("stash ", "G stash ", "G")
        assert.are.equal(true, vim.tbl_contains(result, "push"))
    end)
end)
