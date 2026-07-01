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

---@return string|nil git_root, string|nil filepath
local function current_buffer_git_info()
    local current_file = vim.fn.expand("%:p")
    if current_file == "" then
        vim.notify("Trunks edit: no file in current buffer", vim.log.levels.ERROR)
        return nil, nil
    end
    local git_root = require("trunks._core.parse_command")._find_git_root(current_file)
    -- filepath relative to git root (strip trailing slash from root + separator)
    local filepath = current_file:sub(#git_root + 2)
    return git_root, filepath
end

---@param git_root string
---@param subcmd string
---@return string[], integer
local function run_git(git_root, subcmd)
    local cmd_obj = require("trunks._core.command").base_command(subcmd)
    cmd_obj._pager = nil
    local result = require("trunks._core.run_cmd").system(cmd_obj:build(), { cwd = git_root })
    return result.output, result.code
end

---Parse a unified-diff hunk header into { old_start, old_count, new_start, new_count }.
---Counts default to 1 when omitted (e.g. "@@ -5 +5,2 @@").
---@param header string
---@return integer[]|nil
local function parse_hunk(header)
    local old_start, old_count, new_start, new_count = header:match("^@@ %-(%d+),?(%d*) %+(%d+),?(%d*) @@")
    if not old_start then
        return nil
    end
    return {
        tonumber(old_start),
        old_count == "" and 1 or tonumber(old_count),
        tonumber(new_start),
        new_count == "" and 1 or tonumber(new_count),
    }
end

---@param git_root string
---@param source_rev string|nil
---@param target_rev string|nil
---@param filepath string
---@param line integer
---@return integer line
local function map_line(git_root, source_rev, target_rev, filepath, line)
    if source_rev == target_rev then
        return line
    end

    -- `git diff -U0` prints hunks as `@@ -<old> +<new> @@`.
    local escaped = vim.fn.shellescape(filepath)
    local reverse = false
    local subcmd
    if source_rev and target_rev then
        subcmd = string.format("diff -U0 --no-color %s %s -- %s", source_rev, target_rev, escaped)
    elseif target_rev then
        subcmd = string.format("diff -U0 --no-color %s -- %s", target_rev, escaped)
        reverse = true
    else
        subcmd = string.format("diff -U0 --no-color %s -- %s", source_rev, escaped)
    end

    local output, exit_code = run_git(git_root, subcmd)
    if exit_code ~= 0 then
        return line
    end

    local best
    for _, header in ipairs(output) do
        local hunk = parse_hunk(header)
        if hunk then
            if reverse then
                hunk = { hunk[3], hunk[4], hunk[1], hunk[2] }
            end
            if hunk[1] < line then
                best = hunk
            end
        end
    end
    if not best then
        return line
    end

    local source_start, source_count, target_start, target_count = best[1], best[2], best[3], best[4]
    if source_start + source_count > line then
        -- Cursor is inside the changed hunk: land at the top of the new hunk.
        return target_start + math.max(1 - target_count, 0)
    end
    -- Cursor is past the hunk: shift by the change in line count.
    return target_start + math.max(target_count, 1) + line - source_start - math.max(source_count, 1)
end

---@param uri string
---@param line? integer 1-indexed line to place the cursor on
---@param col? integer 0-indexed column to place the cursor on
local function open_uri(uri, line, col)
    vim.cmd("edit " .. vim.fn.fnameescape(uri))
    if not line then
        return
    end
    local target_line = math.min(math.max(line, 1), vim.api.nvim_buf_line_count(0))
    local line_text = vim.api.nvim_buf_get_lines(0, target_line - 1, target_line, false)[1] or ""
    local target_col = math.min(col or 0, #line_text)
    vim.api.nvim_win_set_cursor(0, { target_line, target_col })
end

-- Supported argument formats (mirrors Fugitive's :Gedit):
--   (none)          - open current file at HEAD
--   <ref>           - run git show <ref> (commit/tree view)
--   <ref>:<path>    - open <path> at <ref>
--   :<path>         - open <path> from the index at HEAD
---@param cmd string The full command string, e.g. "edit HEAD:path/to/file"
function M.render(cmd)
    local cursor = vim.api.nvim_win_get_cursor(0)
    local source_line, source_col = cursor[1], cursor[2]
    local source_rev = vim.b.trunks_commit -- nil for a working-tree file
    local source_path = vim.b.trunks_filepath -- nil for a working-tree file

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
        local line = map_line(git_root, source_rev, hash, source_path or filepath, source_line)
        open_uri(require("trunks._core.virtual_buffers").create_uri(git_root, hash, filepath), line, source_col)
        return
    end

    -- Get git root before switching buffers
    local git_root = require("trunks._core.parse_command")._find_git_root(vim.fn.expand("%:p"))
    if not source_path then
        source_path = vim.fn.expand("%:p"):sub(#git_root + 2)
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
        -- Only preserve the cursor when opening a different version of the same file.
        local line, col
        if filepath == source_path then
            line = map_line(git_root, source_rev, hash, filepath, source_line)
            col = source_col
        end
        open_uri(require("trunks._core.virtual_buffers").create_uri(git_root, hash, filepath), line, col)
    else
        -- Just a ref: show git show output
        open_uri(require("trunks._core.virtual_buffers").create_show_uri(git_root, arg))
    end
end

return M
