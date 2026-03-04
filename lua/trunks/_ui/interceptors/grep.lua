local M = {}

---@param command_builder trunks.Command
local function populate_and_open_quickfix(command_builder)
    -- Clear the current quickfix list
    vim.fn.setqflist({}, "r")

    command_builder.base = command_builder.base:gsub("grep", "grep -n", 1)
    local output, exit_code = require("trunks._core.run_cmd").run_cmd(command_builder)
    if exit_code ~= 0 then
        vim.notify(output[1], vim.log.levels.ERROR)
        return
    end

    vim.cmd.copen()
    local cmd = command_builder:build()
    local grep_output = vim.fn.system(cmd)
    vim.cmd.cexpr(vim.fn.string(grep_output))
end

---@param command_builder trunks.Command
function M.render(command_builder)
    populate_and_open_quickfix(command_builder)
end

return M
