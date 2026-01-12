local parse_log_cmd = require("trunks._ui.home_options.log")._parse_log_cmd
local Command = require("trunks._core.command")

describe("parse_log_cmd", function()
    it("should use native output when a command contains the native-only option", function()
        for _, option in ipairs(require("trunks._ui.home_options.log").GIT_FILETYPE_OPTIONS) do
            local command_builder = Command.base_command("log " .. option)
            assert.are.equal(true, parse_log_cmd(command_builder, "").use_git_filetype_keymaps)
        end
    end)

    it("should use default format for simple filepath log commands", function()
        local command_builder = Command.base_command("log -- somefile.txt")
        assert.is_not_nil(parse_log_cmd(command_builder, "--format=short").cmd:find("--format", 1, true))
    end)
end)
