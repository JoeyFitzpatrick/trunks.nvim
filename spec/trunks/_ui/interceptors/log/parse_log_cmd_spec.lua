local parse_log_cmd = require("trunks._ui.home_options.log")._parse_log_cmd

describe("parse_log_cmd", function()
    it("should use native output when a command contains the native-only option", function()
        for _, option in ipairs(require("trunks._ui.home_options.log").NATIVE_OUTPUT_OPTIONS) do
            local Command = require("trunks._core.command")
            local command_builder = Command.base_command("log " .. option)
            assert.are.equal(true, parse_log_cmd(command_builder).use_native_output)
        end
    end)

    it("should not use native output or show head when a command contains the --follow option", function()
        local Command = require("trunks._core.command")
        local command_builder = Command.base_command("log --follow %")
        assert.are.equal(false, parse_log_cmd(command_builder).use_native_output)
        assert.are.equal(false, parse_log_cmd(command_builder).show_head)
    end)

    it("should show head and not native output when a command contains no options", function()
        local Command = require("trunks._core.command")
        local command_builder = Command.base_command("log some-branch")
        assert.are.equal(true, parse_log_cmd(command_builder).show_head)
        assert.are.equal(false, parse_log_cmd(command_builder).use_native_output)
    end)
end)
