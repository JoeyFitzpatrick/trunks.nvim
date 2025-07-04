---@class trunks.SplitDiffParams
---@field filepath string
---@field commit string

-- Vdiff and Hdiff are 5 characters, plus a space
local SUBCOMMAND_LENGTH = 6

local M = {}

---@param cmd string
---@return trunks.SplitDiffParams
function M._parse_split_diff_args(cmd)
    local args = cmd:sub(SUBCOMMAND_LENGTH)
    local commit = args:match("%S+")
    if not commit then
        return { filepath = vim.fn.expand("%"), commit = "HEAD" }
    end
    return { filepath = vim.fn.expand("%"), commit = commit }
end

---@param command_builder trunks.Command
---@param split_type "below" | "right"
function M.split_diff(command_builder, split_type)
    local args = command_builder:build()
    local params = M._parse_split_diff_args(args)

    vim.cmd("diffthis")
    require("trunks._core.open_file").open_file_in_split(params.filepath, params.commit, split_type)
    vim.cmd("diffthis")
    require("trunks._ui.keymaps.base").set_q_keymap(vim.api.nvim_get_current_buf())
end

return M
