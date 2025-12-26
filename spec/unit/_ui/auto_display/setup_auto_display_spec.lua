local setup_auto_display = require("trunks._ui.auto_display")._setup_auto_display

local default_opts = {
    set_keymaps = function() end,
    set_autocmds = function() end,
    auto_display_config = {},
    auto_display_opts = { strategy = {} },
}

describe("setup_auto_display", function()
    it("should set keymaps and autocmds", function()
        local set_keymaps_called = false
        local set_autocmds_result = {}
        local opts = default_opts
        opts.set_keymaps = function()
            set_keymaps_called = true
        end
        opts.set_autocmds = function(_bufnr, auto_display_opts)
            set_autocmds_result = auto_display_opts
        end
        setup_auto_display(-1, opts)
        assert.are.equal(true, set_keymaps_called)
        assert.are.equal(opts.auto_display_opts, set_autocmds_result)
    end)

    it("should open or not open auto_display depending on config", function()
        local test_map = {
            { config = nil, expected = true },
            { config = {}, expected = true },
            { config = { auto_display_on = true }, expected = true },
            { config = { auto_display_on = false }, expected = false },
        }
        for _, test in ipairs(test_map) do
            local opts = default_opts
            opts.auto_display_config = test.config
            local auto_display_open = setup_auto_display(-1, opts).open_auto_display
            assert.are.equal(test.expected, auto_display_open)
        end
    end)

    it("should return a win size and direction depending on strategy passed in", function()
        local golden_ratio = require("trunks._constants.constants").GOLDEN_RATIO
        local test_map = {
            { strategy = { win_size = 0.12 }, expected = { display_strategy = "below", win_size = 0.12 } },
            -- { strategy = {}, expected = { display_strategy = "below", win_size = golden_ratio } },
            -- {
            --     strategy = { display_strategy = "below" },
            --     expected = { display_strategy = "below", win_size = golden_ratio },
            -- },
            -- {
            --     strategy = { display_strategy = "below", win_size = 0.2 },
            --     expected = { display_strategy = "below", win_size = 0.2 },
            -- },
            -- { strategy = { display_strategy = "right" }, expected = { display_strategy = "right", win_size = 0.5 } },
        }
        for _, test in ipairs(test_map) do
            local opts = default_opts
            opts.auto_display_opts.strategy = test.strategy
            local win_size = setup_auto_display(-1, opts).win_size
            local display_strategy = setup_auto_display(-1, opts).display_strategy
            assert.are.equal(test.expected.win_size, win_size)
            assert.are.equal(test.expected.display_strategy, display_strategy)
        end
    end)
end)
