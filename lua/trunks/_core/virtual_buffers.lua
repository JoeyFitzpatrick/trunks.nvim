---@class trunks.VirtualBufferUri
---@field git_root string The absolute path to the git repository root
---@field commit string The commit hash
---@field filepath string The file path within the repository

local M = {}

-- URI format: trunks://<git_root>/.git//commit/<hash>/<filepath>
--             trunks://<git_root>/.git//show/<ref>

---@param git_root string Absolute path to git repository root
---@param commit string
---@param filepath string The file path (should not start with /)
---@return string uri The trunks:// URI
function M.create_uri(git_root, commit, filepath)
    local normalized_path = filepath:gsub("^/+", "")
    return string.format("trunks://%s/.git//commit/%s/%s", git_root, commit, normalized_path)
end

---@param git_root string Absolute path to git repository root
---@param ref string A git ref (commit hash, branch, tag, etc.)
---@return string uri The trunks:// URI for a git show view
function M.create_show_uri(git_root, ref)
    return string.format("trunks://%s/.git//show/%s", git_root, ref)
end

---@class trunks.Uri
---@field git_root? string
---@field commit string
---@field filepath string
---@field stage? "base" | "ours" | "theirs"

---@param uri string
---@return trunks.Uri
function M.parse_file_uri(uri)
    local rest = uri:sub(#"trunks://" + 1)
    local sep = rest:find("//", 1, true)
    assert(sep, "Trunks: didn't find separator in trunks:// URI")

    local git_root = rest:sub(1, sep - 1):gsub("%.git$", "")
    local spec = rest:sub(sep + 2)
    local commit, filepath = spec:match("^commit/([^/]+)/(.+)$")
    assert(commit and filepath, "Trunks: unable to parse commit and filepath from URI " .. uri)
    return {
        git_root = git_root ~= "" and git_root or nil,
        commit = commit,
        filepath = filepath,
        stage = nil,
    }
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
    local git_root = rest:sub(1, sep - 1):gsub("%.git$", "")
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
    local result = require("trunks._core.run_cmd").system(cmd_obj:build())
    return result.output, vim.v.shell_error
end

---@param bufnr integer
---@param output string[]
---@param hash string
---@param filetype string|nil
local function set_buffer_content(bufnr, output, hash, filetype)
    vim.bo[bufnr].modifiable = true
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, output)
    vim.bo[bufnr].modified = false
    vim.bo[bufnr].modifiable = false
    vim.bo[bufnr].buftype = "nofile"
    vim.bo[bufnr].bufhidden = "delete"
    if filetype then
        vim.bo[bufnr].filetype = filetype
    end
    vim.b[bufnr].trunks_ref = hash
    require("trunks._ui.keymaps.set").set_q_keymap(bufnr)

    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        local buf = vim.api.nvim_win_get_buf(win)
        if buf ~= bufnr and vim.b[buf].trunks_ref then
            vim.api.nvim_win_close(win, true)
        end
    end
end

--- A diff URI is one that contains a number, e.g.
--- trunks://trunks.nvim/git-merge-test/.git//{1, 2, 3}/file.txt
--- The number represents a "stage": 1 = base, 2 = ours, 3 = theirs
---@param uri trunks.Uri
---@return string[] | "error"
local function handle_diff_uri(uri)
    local cmd = string.format("cat-file --filters :%d:%s", uri.stage, uri.filepath)
    local output, exit_code = run_git(uri.git_root, string.format("cat-file --filters :%d:%s", uri.stage, uri.filepath))
    if exit_code ~= 0 or not output or #output == 0 then
        vim.notify("Trunks: failed to run " .. cmd, vim.log.levels.ERROR)
        return "error"
    end
    return output
end

---@param uri trunks.Uri
---@return string[] | "error"
local function handle_file_uri(uri)
    local output, exit_code = run_git(uri.git_root, string.format("show %s:%s", uri.commit, uri.filepath))

    if exit_code ~= 0 or not output or #output == 0 then
        vim.notify(
            string.format("Failed to read file %s at commit %s", uri.filepath, uri.commit:sub(1, 7)),
            vim.log.levels.ERROR
        )
        return "error"
    end
    return output
end

---@param bufnr integer
---@param uri string
---@return boolean success
local function load_virtual_buffer_content(bufnr, uri)
    -- Handle trunks://<root>//show/<ref> URIs
    local git_root, show_ref = M.parse_show_uri(uri)
    if show_ref then
        local format = "commit %H%n"
            .. "tree   %T%n"
            .. "parent %P%n"
            .. "Author: %an <%ae>%n"
            .. "Date:   %ad%n%n"
            .. "%w(0,4,4)%B"
        local output, exit_code = run_git(git_root, string.format("show --format='%s' %s", format, show_ref))
        if exit_code ~= 0 or not output or #output == 0 then
            vim.notify("Trunks: failed to run git show for '" .. show_ref .. "'", vim.log.levels.ERROR)
            return false
        end
        set_buffer_content(bufnr, output, show_ref, "git")
        require("trunks._ui.keymaps.git_filetype_keymaps").set_keymaps(bufnr)
        return true
    end

    -- Handle trunks://<root>//commit/<hash>/<filepath> URIs
    local parsed_uri = M.parse_file_uri(uri)
    local commit = parsed_uri.commit
    local filepath = parsed_uri.filepath

    local output
    if parsed_uri.stage then
        output = handle_diff_uri(parsed_uri)
    else
        output = handle_file_uri(parsed_uri)
    end

    if output == "error" then
        return false
    end

    local ft = vim.filetype.match({ filename = filepath })
    set_buffer_content(bufnr, output, commit, ft)

    vim.b[bufnr].trunks_commit = commit
    vim.b[bufnr].trunks_filepath = filepath
    vim.b[bufnr].original_filename = filepath

    return true
end

local EXCLUDED_URIS = {
    ["trunks://status"] = true,
    ["trunks://branch"] = true,
}

local function is_excluded_uri(uri)
    return EXCLUDED_URIS[uri] or false
end

function M.setup()
    local group = vim.api.nvim_create_augroup("TrunksVirtualBuffers", { clear = true })

    vim.api.nvim_create_autocmd("BufReadCmd", {
        group = group,
        pattern = "trunks://*",
        callback = function(args)
            if is_excluded_uri(args.file) then
                return
            end
            load_virtual_buffer_content(args.buf, args.file)
        end,
        desc = "Trunks: Load virtual buffer content from git",
    })

    -- Fallback: ensure content is loaded when buffer is displayed in a window
    vim.api.nvim_create_autocmd("BufWinEnter", {
        group = group,
        pattern = "trunks://*",
        callback = function(args)
            if is_excluded_uri(args.file) then
                return
            end

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
