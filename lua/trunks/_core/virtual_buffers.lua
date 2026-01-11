---@class trunks.VirtualBufferUri
---@field commit string The commit hash
---@field filepath string The file path within the repository

local M = {}

---Create a virtual buffer URI for a file at a specific commit
---@param commit string The commit hash or reference
---@param filepath string The file path (should not start with /)
---@return string uri The trunks:// URI
function M.create_uri(commit, filepath)
    -- Normalize filepath to not start with /
    local normalized_path = filepath:gsub("^/+", "")
    return string.format("trunks://commit/%s/%s", commit, normalized_path)
end

---Parse a virtual buffer URI into its components
---@param uri string The trunks:// URI
---@return string|nil commit The commit hash, or nil if parse fails
---@return string|nil filepath The file path, or nil if parse fails
function M.parse_uri(uri)
    local commit, filepath = uri:match("^trunks://commit/([^/]+)/(.+)$")
    return commit, filepath
end

---Check if a buffer name is a virtual buffer URI
---@param bufname string The buffer name to check
---@return boolean
function M.is_virtual_uri(bufname)
    return vim.startswith(bufname, "trunks://")
end

---Load content for a virtual buffer
---@param bufnr integer
---@param uri string
---@return boolean success
local function load_virtual_buffer_content(bufnr, uri)
    local commit, filepath = M.parse_uri(uri)

    if not commit or not filepath then
        vim.notify("Invalid trunks:// URI: " .. uri, vim.log.levels.ERROR)
        return false
    end

    -- Run git command to get file content
    local cmd = string.format("git show %s:%s", commit, filepath)
    local output = require("trunks._core.run_cmd").run_cmd(cmd, { no_pager = true })

    if not output or #output == 0 then
        vim.notify(
            string.format("Failed to read file %s at commit %s", filepath, commit:sub(1, 7)),
            vim.log.levels.ERROR
        )
        return false
    end

    -- Clear the buffer and populate with git output
    vim.bo[bufnr].modifiable = true
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, output)

    -- Set buffer options
    vim.bo[bufnr].modified = false
    vim.bo[bufnr].modifiable = false
    vim.bo[bufnr].buftype = "nofile"
    vim.bo[bufnr].bufhidden = "hide"

    -- Set filetype for syntax highlighting
    local ft = vim.filetype.match({ filename = filepath })
    if ft then
        vim.bo[bufnr].filetype = ft
    end

    -- Store metadata for later use
    vim.b[bufnr].trunks_commit = commit
    vim.b[bufnr].trunks_filepath = filepath

    return true
end

---Setup autocommands to handle virtual buffer URIs
function M.setup()
    local group = vim.api.nvim_create_augroup("TrunksVirtualBuffers", { clear = true })

    -- Handle reading virtual buffers
    vim.api.nvim_create_autocmd("BufReadCmd", {
        group = group,
        pattern = "trunks://*",
        callback = function(args)
            load_virtual_buffer_content(args.buf, args.file)
        end,
        desc = "Trunks: Load virtual buffer content from git",
    })

    -- Fallback: ensure content is loaded when buffer is displayed in a window
    vim.api.nvim_create_autocmd("BufWinEnter", {
        group = group,
        pattern = "trunks://*",
        callback = function(args)
            -- Only load if buffer is empty (content wasn't loaded yet)
            local line_count = vim.api.nvim_buf_line_count(args.buf)
            local first_line = vim.api.nvim_buf_get_lines(args.buf, 0, 1, false)[1]

            if line_count == 1 and (first_line == "" or first_line == nil) then
                load_virtual_buffer_content(args.buf, args.file)
            end
        end,
        desc = "Trunks: Ensure virtual buffer content is loaded",
    })

    -- Handle write attempts (disallow writing to past commits)
    vim.api.nvim_create_autocmd("BufWriteCmd", {
        group = group,
        pattern = "trunks://*",
        callback = function(args)
            vim.notify("Cannot write to a git commit buffer", vim.log.levels.WARN)
            vim.bo[args.buf].modified = false -- Clear modified flag
        end,
        desc = "Trunks: Prevent writing to virtual buffers",
    })
end

return M
