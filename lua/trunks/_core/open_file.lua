---@class trunks.OpenFileOpts
---@field original_filename? string

local M = {}

---@param filename string
---@param commit string
local function get_filename(filename, commit)
    return commit .. "--" .. filename
end

--- It is worth noting that this could potentially delete a buffer that
--- is not the one we are looking for, because we're just using `find`
--- on the filename, and other paths could contain this. Worth fixing
--- at some point.
---@param name string
local function delete_existing_buffer(name)
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        local buf_name = vim.api.nvim_buf_get_name(buf)
        if buf_name:find(name, 1, true) then
            vim.api.nvim_buf_delete(buf, { force = true })
            return
        end
    end
end

--- Ensures a virtual buffer's content is loaded by explicitly triggering BufReadCmd if empty
---@param bufnr integer
local function ensure_buffer_loaded(bufnr)
    vim.schedule(function()
        local line_count = vim.api.nvim_buf_line_count(bufnr)
        local first_line = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1]
        if line_count == 1 and (first_line == "" or first_line == nil) then
            vim.api.nvim_exec_autocmds("BufReadCmd", { buffer = bufnr })
        end
    end)
end

--- This function assumes that we've already checked to see if there's
--- an open buffer for this file/commit.
---@param bufnr integer
---@param filename string
---@param commit string
---@param opts trunks.OpenFileOpts
local function setup_git_file(bufnr, filename, commit, opts)
    vim.bo[bufnr].filetype = vim.filetype.match({ buf = bufnr }) or ""

    vim.b[bufnr].original_filename = opts.original_filename or filename
    vim.b[bufnr].trunks_commit = commit

    require("trunks._ui.keymaps.set").set_q_keymap(bufnr)
end

local split_to_vim_cmd = {
    above = "aboveleft split",
    below = "rightbelow split",
    right = "rightbelow vsplit",
    left = "aboveleft vsplit",
}

---@param filename string
---@param commit string
---@param split "above" | "below" | "right" | "left"
---@param opts trunks.OpenFileOpts
---@return integer -- bufnr of created buffer
function M.open_file_in_split(filename, commit, split, opts)
    delete_existing_buffer(get_filename(filename, commit))
    local file_at_commit_uri = require("trunks._core.virtual_buffers").create_uri(commit, filename)
    vim.print(file_at_commit_uri)
    vim.cmd(split_to_vim_cmd[split] .. " " .. file_at_commit_uri)
    local bufnr = vim.api.nvim_get_current_buf()
    ensure_buffer_loaded(bufnr)
    setup_git_file(bufnr, filename, commit, opts)
    return bufnr
end

---@param filename string
---@param commit string
---@param opts trunks.OpenFileOpts
---@return integer -- bufnr of created buffer
function M.open_file_in_tab(filename, commit, opts)
    vim.cmd("tabnew")
    delete_existing_buffer(get_filename(filename, commit))
    local file_at_commit_uri = require("trunks._core.virtual_buffers").create_uri(commit, filename)
    vim.cmd("e " .. file_at_commit_uri)
    local bufnr = vim.api.nvim_get_current_buf()
    ensure_buffer_loaded(bufnr)
    setup_git_file(bufnr, filename, commit, opts)
    return bufnr
end

---@param filename string
---@param commit string
---@param opts trunks.OpenFileOpts
---@return integer -- bufnr of created buffer
function M.open_file_in_current_window(filename, commit, opts)
    delete_existing_buffer(get_filename(filename, commit))
    local file_at_commit_uri = require("trunks._core.virtual_buffers").create_uri(commit, filename)
    vim.cmd("e " .. file_at_commit_uri)
    local bufnr = vim.api.nvim_get_current_buf()
    ensure_buffer_loaded(bufnr)
    setup_git_file(bufnr, filename, commit, opts)
    return bufnr
end

return M
