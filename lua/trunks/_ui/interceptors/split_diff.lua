---@class trunks.SplitDiffParams
---@field filepath string
---@field left_commit string|nil
---@field right_commit string|nil

-- Vdiff and Hdiff are 5 characters, plus a space
local SUBCOMMAND_LENGTH = 6

local M = {}

---@param cmd string
---@return trunks.SplitDiffParams
function M._parse_split_diff_args(cmd)
    local args = cmd and cmd:sub(SUBCOMMAND_LENGTH + 1) or ""
    local filepath = vim.b[vim.api.nvim_get_current_buf()].original_filename or vim.fn.expand("%")

    local commits = require("trunks._core.git").parse_commit_range(args)

    return {
        filepath = filepath,
        left_commit = commits.left,
        right_commit = commits.right,
    }
end

---@param cmd string
---@param split_type "below" | "right"
function M.split_diff(cmd, split_type)
    local params = M._parse_split_diff_args(cmd)

    if params.right_commit then
        -- Two commits specified: open both versions and diff them
        require("trunks._core.open_file").open_file_in_current_window(params.filepath, params.left_commit, {})
        local left_bufnr = vim.api.nvim_get_current_buf()
        vim.cmd("diffthis")

        require("trunks._core.open_file").open_file_in_split(params.filepath, params.right_commit, split_type, {})
        local right_bufnr = vim.api.nvim_get_current_buf()
        vim.cmd("diffthis")

        vim.api.nvim_create_autocmd({ "BufHidden" }, {
            buffer = left_bufnr,
            command = "diffoff",
            desc = "Trunks: turn off diff mode for left side",
        })

        vim.api.nvim_create_autocmd({ "BufHidden" }, {
            buffer = right_bufnr,
            command = "diffoff",
            desc = "Trunks: turn off diff mode for right side",
        })
    else
        -- Single commit: diff current buffer against commit version
        local bufnr = vim.api.nvim_get_current_buf()

        vim.cmd("diffthis")
        require("trunks._core.open_file").open_file_in_split(params.filepath, params.left_commit, split_type, {})
        local split_bufnr = vim.api.nvim_get_current_buf()
        vim.cmd("diffthis")

        vim.api.nvim_create_autocmd({ "BufHidden" }, {
            buffer = bufnr,
            command = "diffoff",
            desc = "Trunks: turn off diff mode for file that split diff was based on",
        })

        vim.api.nvim_create_autocmd({ "BufHidden" }, {
            buffer = split_bufnr,
            command = "diffoff",
            desc = "Trunks: turn off diff mode for split diff",
        })
    end
end

return M
