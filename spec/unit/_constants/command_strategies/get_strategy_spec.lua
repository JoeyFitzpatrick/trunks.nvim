local get_strategy = require("trunks._constants.command_strategies").get_strategy
local default_strategy = require("trunks._constants.command_strategies").default

describe("get_strategy", function()
    before_each(function()
        require("trunks._constants.command_strategies").fake = nil
    end)

    it("should return the default strategy when a command can't be parsed", function()
        local strategy = get_strategy("git nope")
        assert.are.same(strategy, default_strategy)
    end)

    it("should return the strategy for a specific command", function()
        local mock_strategy = vim.tbl_extend("force", default_strategy, { test = true })
        require("trunks._constants.command_strategies").fake = mock_strategy
        local strategy = get_strategy("git fake")
        assert.are.same(strategy, mock_strategy)
    end)

    it("should return the strategy for a specific command when a prefix flag is used", function()
        local mock_strategy = vim.tbl_extend("force", default_strategy, { test = true })
        require("trunks._constants.command_strategies").fake = mock_strategy
        local strategy = get_strategy("git --no-pager fake")
        assert.are.same(strategy, mock_strategy)
    end)

    it("should override strategy properties with opts passed in", function()
        local mock_strategy = vim.tbl_extend("force", default_strategy, { test = true })
        require("trunks._constants.command_strategies").fake = mock_strategy
        local strategy = get_strategy("git --no-pager fake", { display_strategy = "left" })

        local expected_strategy = vim.tbl_extend("force", mock_strategy, { display_strategy = "left" })
        assert.are.same(strategy, expected_strategy)
    end)

    it("should override strategy properties with opts when using default strategy", function()
        local strategy = get_strategy("git fake", { display_strategy = "left" })

        local expected_strategy = vim.tbl_extend("force", default_strategy, { display_strategy = "left" })
        assert.are.same(strategy, expected_strategy)
    end)

    it("should return the final strategy when some properties are function", function()
        local mock_strategy = vim.tbl_extend("force", default_strategy, {
            test = function(split_cmd)
                return split_cmd
            end,
        })
        require("trunks._constants.command_strategies").fake = mock_strategy
        local cmd = "git --no-pager fake"
        local strategy = get_strategy(cmd)

        assert.are.same(vim.split(cmd, " "), strategy.test)
    end)
end)
