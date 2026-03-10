---@class trunks.VirtualBufferUri
---@field git_root string The absolute path to the git repository root
---@field commit string The commit hash
---@field filepath string The file path within the repository

local M = {}

-- URI format: trunks://<git_root>//commit/<hash>/<filepath>
--             trunks://<git_root>//show/<ref>
-- The `//` separates the git root from the object spec.

---@param git_root string Absolute path to git repository root
---@param commit string
---@param filepath string The file path (should not start with /)
---@return string uri The trunks:// URI
function M.create_uri(git_root, commit, filepath)
    local normalized_path = filepath:gsub("^/+", "")
    return string.format("trunks://%s//commit/%s/%s", git_root, commit, normalized_path)
end

---@param git_root string Absolute path to git repository root
---@param ref string A git ref (commit hash, branch, tag, etc.)
---@return string uri The trunks:// URI for a git show view
function M.create_show_uri(git_root, ref)
    return string.format("trunks://%s//show/%s", git_root, ref)
end

---@param uri string
---@return string|nil git_root
---@return string|nil commit
---@return string|nil filepath
function M.parse_uri(uri)
    local rest = uri:sub(#"trunks://" + 1)
    local sep = rest:find("//", 1, true)
    if not sep then
        return nil, nil, nil
    end
    local git_root = rest:sub(1, sep - 1)
    local spec = rest:sub(sep + 2)
    local commit, filepath = spec:match("^commit/([^/]+)/(.+)$")
    return git_root ~= "" and git_root or nil, commit, filepath
end

---@param uri string
---@return string|nil git_root
---@return string|nil ref
function M.parse_show_uri(uri)
    local rest = uri:sub(#"trunks://" + 1)
    local sep = rest:find("//", 1, true)
    if not sep then
        return nil, nil
    end
    local git_root = rest:sub(1, sep - 1)
    local spec = rest:sub(sep + 2)
    local ref = spec:match("^show/(.+)$")
    return git_root ~= "" and git_root or nil, ref
end

---@param bufname string
---@return boolean
function M.is_virtual_uri(bufname)
    return vim.startswith(bufname, "trunks://")
end

---Run a git subcommand in the given repository root, without pager.
---@param git_root string|nil
---@param subcmd string
---@return string[], integer
local function run_git(git_root, subcmd)
    local cmd_obj = require("trunks._core.command").base_command(subcmd, git_root)
    cmd_obj._pager = nil
    local output = vim.fn.systemlist(cmd_obj:build())
    return output, vim.v.shell_error
end

---@param bufnr integer
---@param output string[]
---@param filetype string|nil
local function set_buffer_content(bufnr, output, filetype)
    vim.bo[bufnr].modifiable = true
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, output)
    vim.bo[bufnr].modified = false
    vim.bo[bufnr].modifiable = false
    vim.bo[bufnr].buftype = "nofile"
    vim.bo[bufnr].bufhidden = "delete"
    if filetype then
        vim.bo[bufnr].filetype = filetype
    end
    require("trunks._ui.keymaps.set").set_q_keymap(bufnr)
end

---@param bufnr integer
---@param uri string
---@return boolean success
local function load_virtual_buffer_content(bufnr, uri)
    -- Handle trunks://<root>//show/<ref> URIs
    local git_root, show_ref = M.parse_show_uri(uri)
    if show_ref then
        local output, exit_code = run_git(git_root, string.format("show --pretty=medium %s", show_ref))
        if exit_code ~= 0 or not output or #output == 0 then
            vim.notify("Trunks: failed to run git show for '" .. show_ref .. "'", vim.log.levels.ERROR)
            return false
        end
        set_buffer_content(bufnr, output, "git")
        vim.b[bufnr].trunks_ref = show_ref
        require("trunks._ui.keymaps.git_filetype_keymaps").set_keymaps(bufnr)

        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
            local buf = vim.api.nvim_win_get_buf(win)
            if buf ~= bufnr and vim.b[buf].trunks_ref then
                vim.api.nvim_win_close(win, true)
            end
        end

        return true
    end

    -- Handle trunks://<root>//commit/<hash>/<filepath> URIs
    local commit, filepath
    git_root, commit, filepath = M.parse_uri(uri)

    if not commit or not filepath then
        vim.notify("Invalid trunks:// URI: " .. uri, vim.log.levels.ERROR)
        return false
    end

    local output, exit_code = run_git(git_root, string.format("show %s:%s", commit, filepath))

    if exit_code ~= 0 or not output or #output == 0 then
        vim.notify(
            string.format("Failed to read file %s at commit %s", filepath, commit:sub(1, 7)),
            vim.log.levels.ERROR
        )
        return false
    end

    local ft = vim.filetype.match({ filename = filepath })
    set_buffer_content(bufnr, output, ft)

    vim.b[bufnr].trunks_commit = commit
    vim.b[bufnr].trunks_filepath = filepath

    return true
end

function M.setup()
    local group = vim.api.nvim_create_augroup("TrunksVirtualBuffers", { clear = true })

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
end

return M
