describe("command", function()
    it("can build a command", function()
        local Command = require("trunks._core.command")
        local cmd = Command.base_command("log"):build()
        assert.are.equal("git --no-pager log", cmd)
    end)

    it("adds prefix args to a command", function()
        local Command = require("trunks._core.command")
        local cmd = Command.base_command("log"):add_prefix_args("-c foo.bar=true"):build()
        assert.are.equal("git --no-pager -c foo.bar=true log", cmd)
    end)

    it("adds regular args to a command", function()
        local Command = require("trunks._core.command")
        local cmd = Command.base_command("log"):add_args("--grep ohyeah"):build()
        assert.are.equal("git --no-pager log --grep ohyeah", cmd)
    end)

    it("adds postfix args to a command", function()
        local Command = require("trunks._core.command")
        local cmd = Command.base_command("log"):add_postfix_args("-- some/file/path"):add_args("--grep ohyeah"):build()
        assert.are.equal("git --no-pager log --grep ohyeah -- some/file/path", cmd)
    end)

    it("can build a long command with multiple steps", function()
        local Command = require("trunks._core.command")
        local cmd = Command.base_command("log"):add_postfix_args("-- some/file/path"):add_args("--grep ohyeah")
        cmd:add_prefix_args("-c foo.bar=true")
        cmd:add_args("-S 'some search term'")
        local final_cmd = cmd:build()
        assert.are.equal(
            "git --no-pager -c foo.bar=true log --grep ohyeah -S 'some search term' -- some/file/path",
            final_cmd
        )
    end)

    it("can add a pager to a command", function()
        local Command = require("trunks._core.command")
        local cmd = Command.base_command("log")
        cmd._pager = "delta"
        assert.are.equal("git --no-pager log | delta --paging=never", cmd:build())
    end)
end)

describe("command for file in different repo", function()
    before_each(function()
        vim.api.nvim_buf_get_name = function()
            return "fake-repo/fake-file.txt"
        end
        require("trunks._core.parse_command")._find_git_root = function()
            return "fake-repo"
        end
    end)
    it("prefixes a command with a -C flag if the current buffer is in a different repo", function()
        local Command = require("trunks._core.command")
        local cmd = Command.base_command("log"):build()
        assert.are.equal("git -C 'fake-repo' --no-pager log", cmd)
    end)

    it("prefixes -C arg before given prefix args", function()
        local Command = require("trunks._core.command")
        local cmd = Command.base_command("log"):add_prefix_args("-c foo.bar=true"):build()
        assert.are.equal("git -C 'fake-repo' --no-pager -c foo.bar=true log", cmd)
    end)

    it("adds an adapter when needed", function()
        local Command = require("trunks._core.command")
        local cmd = Command.base_command("log"):add_prefix_args("-c foo.bar=true"):build()
        assert.are.equal("git -C 'fake-repo' --no-pager -c foo.bar=true log", cmd)
    end)
end)
