---@class trunks.SplitDiffParams
---@field filepath string
---@field commit string

-- Vdiff and Hdiff are 5 characters, plus a space
local SUBCOMMAND_LENGTH = 6

local M = {}

---@param command_builder trunks.Command
---@return trunks.SplitDiffParams
function M._parse_split_diff_args(command_builder)
    local cmd = command_builder.base
    local args = cmd and cmd:sub(SUBCOMMAND_LENGTH) or ""
    local filepath = vim.b[vim.api.nvim_get_current_buf()].original_filename or vim.fn.expand("%")

    local commit = args:match("%S+")
    return { filepath = filepath, commit = commit or "HEAD" }
end

---@param command_builder trunks.Command
---@param split_type "below" | "right"
function M.split_diff(command_builder, split_type)
    local params = M._parse_split_diff_args(command_builder)

    vim.cmd("diffthis")
    require("trunks._core.open_file").open_file_in_split(params.filepath, params.commit, split_type)
    vim.cmd("diffthis")
    require("trunks._ui.keymaps.base").set_q_keymap(vim.api.nvim_get_current_buf())
end

return M
