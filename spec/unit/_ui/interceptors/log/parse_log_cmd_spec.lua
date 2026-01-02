local parse_log_cmd = require("trunks._ui.home_options.log")._parse_log_cmd

describe("parse_log_cmd", function()
    it("should use native output when a command contains the native-only option", function()
        for _, option in ipairs(require("trunks._ui.home_options.log").GIT_FILETYPE_OPTIONS) do
            local Command = require("trunks._core.command")
            local command_builder = Command.base_command("log " .. option)
            assert.are.equal(true, parse_log_cmd(command_builder).use_git_filetype_keymaps)
        end
    end)
end)
