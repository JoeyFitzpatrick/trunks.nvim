local parse_log_cmd = require("trunks._ui.home_options.log")._parse_log_cmd

describe("parse_log_cmd", function()
    it("should use native output when a command contains the native-only option", function()
        for _, option in ipairs(require("trunks._ui.home_options.log").NATIVE_OUTPUT_OPTIONS) do
            assert.are.equal(true, parse_log_cmd("log " .. option).use_native_output)
        end
    end)

    it("should not use native output or show head when a command contains the --follow option", function()
        assert.are.equal(false, parse_log_cmd("log --follow %").use_native_output)
        assert.are.equal(false, parse_log_cmd("log --follow %").show_head)
    end)

    it("should show head when a command contains just a branch", function()
        assert.are.equal(true, parse_log_cmd("log some-branch").show_head)
    end)

    it("should show head and not native output when a command contains no options", function()
        assert.are.equal(true, parse_log_cmd("log some-branch").show_head)
        assert.are.equal(false, parse_log_cmd("log some-branch").use_native_output)
    end)
end)
