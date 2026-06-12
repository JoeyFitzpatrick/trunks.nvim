---@class trunks.SplitDiffParams
---@field filepath string
---@field left_commit string|nil
---@field right_commit string|nil
---@field split_type "below" | "right"
---@field bang? boolean

-- Vdiff and Hdiff are 5 characters, plus a space
local SUBCOMMAND_LENGTH = 6

local M = {}

---@param cmd string
---@return trunks.SplitDiffParams
function M._parse_split_diff_args(cmd)
    local args = cmd and cmd:sub(SUBCOMMAND_LENGTH + 1) or ""
    local filepath = vim.b[vim.api.nvim_get_current_buf()].original_filename or vim.fn.expand("%:~:.")

    local commits = require("trunks._core.git").parse_commit_range(args)

    return {
        filepath = filepath,
        left_commit = commits.left,
        right_commit = commits.right,
        split_type = "right",
    }
end

---@param filename string
---@return string git_root
local function get_git_root(filename)
    return require("trunks._core.parse_command")._find_git_root(filename) or vim.loop.cwd()
end

local function set_diffoff_autocmd(bufnr, buffer_desc)
    vim.api.nvim_create_autocmd({ "BufHidden" }, {
        buffer = bufnr,
        command = "diffoff",
        desc = "Trunks: turn off diff mode for " .. buffer_desc,
    })
end

---@param filepath string
---@return boolean
local function has_merge_conflicts(filepath)
    local output, exit_code = require("trunks._core.run_cmd").run_cmd("ls-files --unmerged -- " .. filepath)
    return exit_code == 0 and #output > 0
end

---@class trunks.DiffBufnrs
---@field ours_bufnr integer
---@field theirs_bufnr integer

---@param params trunks.SplitDiffParams
local function open_merge_conflict_buffers(params)
    vim.cmd("tab split")
    local bufnr = vim.api.nvim_get_current_buf()
    local ours_stage = "2"
    local theirs_stage = "3"
    local filepath = params.filepath
    local ours_file_uri =
        require("trunks._core.virtual_buffers").create_diff_uri(get_git_root(filepath), filepath, ours_stage)
    local theirs_file_uri =
        require("trunks._core.virtual_buffers").create_diff_uri(get_git_root(filepath), filepath, theirs_stage)

    local win = vim.api.nvim_get_current_win()
    if params.split_type == "right" then
        vim.cmd("vertical leftabove diffsplit " .. ours_file_uri)
    else
        vim.cmd("aboveleft diffsplit " .. ours_file_uri)
    end
    local ours_bufnr = vim.api.nvim_get_current_buf()
    vim.api.nvim_set_current_win(win)

    if params.split_type == "right" then
        vim.cmd("vertical rightbelow diffsplit " .. theirs_file_uri)
    else
        vim.cmd("belowright diffsplit " .. theirs_file_uri)
    end
    local theirs_bufnr = vim.api.nvim_get_current_buf()
    vim.api.nvim_set_current_win(win)

    set_diffoff_autocmd(bufnr, "file with merge conflicts")
    set_diffoff_autocmd(ours_bufnr, "our changes")
    set_diffoff_autocmd(theirs_bufnr, "their changes")
    require("trunks._ui.keymaps.diff_keymaps").set_diff_keymaps(
        bufnr,
        { ours_bufnr = ours_bufnr, theirs_bufnr = theirs_bufnr }
    )
    require("trunks._ui.keymaps.keymaps_text").show_in_cmdline(bufnr, { "trunks_diff" })
end

---@param cmd string
---@param split_params trunks.SplitDiffParams
function M.split_diff(cmd, split_params)
    local params = vim.tbl_extend("force", M._parse_split_diff_args(cmd), split_params)
    local filepath = params.filepath

    if params.bang and has_merge_conflicts(filepath) then
        open_merge_conflict_buffers(params)
        return
    end

    if params.left_commit ~= require("trunks._constants.constants").WORKING_TREE then
        -- Two commits specified: open both versions and diff them
        require("trunks._core.open_file").open_file_in_current_window(filepath, params.left_commit, {})
        local left_bufnr = vim.api.nvim_get_current_buf()
        vim.cmd("diffthis")

        require("trunks._core.open_file").open_file_in_split(filepath, params.right_commit, params.split_type, {})
        local right_bufnr = vim.api.nvim_get_current_buf()
        vim.cmd("diffthis")

        set_diffoff_autocmd(left_bufnr, "left side")
        set_diffoff_autocmd(right_bufnr, "right side")
    else
        -- Single commit: diff current buffer against commit version
        local bufnr = vim.api.nvim_get_current_buf()
        local file_at_commit_uri = require("trunks._core.virtual_buffers").create_uri(
            get_git_root(filepath),
            params.right_commit,
            params.filepath
        )

        if params.split_type == "right" then
            vim.cmd("vertical diffsplit " .. file_at_commit_uri)
        else
            vim.cmd("diffsplit " .. file_at_commit_uri)
        end
        local split_bufnr = vim.api.nvim_get_current_buf()

        set_diffoff_autocmd(bufnr, "file split diff was based on")
        set_diffoff_autocmd(split_bufnr, "split diff")
    end
end

function M.split_diff_file() end

return M
