local M = {}

---@param ref string
---@return string|nil hash, string|nil err
local function resolve_ref(ref)
    local lines, exit_code = require("trunks._core.run_cmd").run_cmd("rev-parse " .. ref, { no_pager = true })
    if exit_code ~= 0 or not lines[1] then
        return nil, "Trunks edit: cannot resolve ref '" .. ref .. "'"
    end
    return lines[1], nil
end

---Get the git root and relative filepath for the current buffer.
---@return string|nil git_root, string|nil filepath
local function current_buffer_git_info()
    local current_file = vim.fn.expand("%:p")
    if current_file == "" then
        vim.notify("Trunks edit: no file in current buffer", vim.log.levels.ERROR)
        return nil, nil
    end
    local git_root = require("trunks._core.parse_command")._find_git_root(current_file)
    if not git_root then
        vim.notify("Trunks edit: not in a git repository", vim.log.levels.ERROR)
        return nil, nil
    end
    -- filepath relative to git root (strip trailing slash from root + separator)
    local filepath = current_file:sub(#git_root + 2)
    return git_root, filepath
end

---Open a trunks virtual buffer URI in the current window.
---@param uri string
local function open_uri(uri)
    vim.cmd("edit " .. vim.fn.fnameescape(uri))
end

-- Supported argument formats (mirrors Fugitive's :Gedit):
--   (none)          - open current file at HEAD
--   <ref>           - run git show <ref> (commit/tree view)
--   <ref>:<path>    - open <path> at <ref>
--   :<path>         - open <path> from the index at HEAD
---@param cmd string The full command string, e.g. "edit HEAD:path/to/file"
function M.render(cmd)
    local arg = cmd:match("^edit%s+(.*)")
    if arg then
        arg = require("trunks._core.parse_command").expand_special_characters(arg)
    end
    if not arg or arg:match("^%s*$") then
        -- No argument: open current buffer's file at HEAD
        local git_root, filepath = current_buffer_git_info()
        if not git_root then
            return
        end
        local hash, err = resolve_ref("HEAD")
        if not hash then
            vim.notify(err, vim.log.levels.ERROR)
            return
        end
        open_uri(require("trunks._core.virtual_buffers").create_uri(git_root, hash, filepath))
        return
    end

    -- Get git root from current buffer context (before switching buffers)
    local git_root = require("trunks._core.parse_command")._find_git_root(vim.fn.expand("%:p"))
    if not git_root then
        vim.notify("Trunks edit: not in a git repository", vim.log.levels.ERROR)
        return
    end

    local colon_pos = arg:find(":")
    if colon_pos then
        -- ref:path format (empty ref means HEAD)
        local ref = arg:sub(1, colon_pos - 1)
        local filepath = arg:sub(colon_pos + 1)
        if filepath == "" then
            vim.notify("Trunks edit: no file path specified after ':'", vim.log.levels.ERROR)
            return
        end

        local resolve = ref ~= "" and ref or "HEAD"
        local hash, err = resolve_ref(resolve)
        if not hash then
            vim.notify(err, vim.log.levels.ERROR)
            return
        end
        open_uri(require("trunks._core.virtual_buffers").create_uri(git_root, hash, filepath))
    else
        -- Just a ref: show git show output
        open_uri(require("trunks._core.virtual_buffers").create_show_uri(git_root, arg))
    end
end

return M
