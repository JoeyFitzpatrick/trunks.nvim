---@class trunks.DiffHunk
---@field filename string
---@field filetype string
---@field start_line integer -- 0-indexed line number where code starts (after @@)
---@field end_line integer -- 0-indexed line number where code ends

local M = {}

---@param line string
---@return string|nil
local function extract_filename(line)
    -- Match patterns like "diff --git a/path/to/file.lua b/path/to/file.lua"
    -- or "+++ b/path/to/file.lua" or "--- a/path/to/file.lua"
    local patterns = {
        "^diff %-%- git [ac]/(.+) [bw]/",
        "^%+%+%+ [bw]/(.+)",
        "^%-%-%- [ac]/(.+)",
    }

    for _, pattern in ipairs(patterns) do
        local match = line:match(pattern)
        if match then
            return match
        end
    end
    return nil
end

---Parse diff output to identify hunks and their corresponding filetypes
---@param bufnr integer
---@return trunks.DiffHunk[]
local function parse_diff_hunks(bufnr)
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local hunks = {}
    local current_filename = nil
    local current_filetype = nil
    local hunk_start = nil

    for i, line in ipairs(lines) do
        local line_idx = i - 1 -- Convert to 0-indexed

        -- Check if this is a diff header
        local filename = extract_filename(line)
        if filename then
            current_filename = filename
            current_filetype = vim.filetype.match({ filename = filename })
        end

        -- Check if this is a hunk header (@@)
        if line:match("^@@") and current_filename and current_filetype then
            -- Close previous hunk if exists
            if hunk_start then
                table.insert(hunks, {
                    filename = current_filename,
                    filetype = current_filetype,
                    start_line = hunk_start,
                    end_line = line_idx - 1,
                })
            end
            -- Start new hunk (code starts on next line)
            hunk_start = line_idx + 1
        end

        -- Check if we hit another diff header (starts with "diff")
        if line:match("^diff %-%-") and hunk_start then
            -- Close current hunk
            table.insert(hunks, {
                filename = current_filename,
                filetype = current_filetype,
                start_line = hunk_start,
                end_line = line_idx - 1,
            })
            hunk_start = nil
        end
    end

    -- Close final hunk if exists
    if hunk_start and current_filename and current_filetype then
        table.insert(hunks, {
            filename = current_filename,
            filetype = current_filetype,
            start_line = hunk_start,
            end_line = #lines - 1,
        })
    end

    return hunks
end

---Get line type and content without diff marker
---@param line string
---@return "added"|"removed"|"context"|"other", string
local function get_line_info(line)
    if line:match("^%+") and not line:match("^%+%+%+") then
        return "added", line:sub(2)
    elseif line:match("^%-") and not line:match("^%-%-%-") then
        return "removed", line:sub(2)
    elseif line:match("^ ") then
        return "context", line:sub(2)
    else
        return "other", line
    end
end

---Remove diff markers from buffer and track line types
---@param bufnr integer
---@return table<integer, "added"|"removed"|"context"|"other"> -- Map of line_idx to line type
local function strip_diff_markers_from_buffer(bufnr)
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local new_lines = {}
    local line_types = {}

    for i, line in ipairs(lines) do
        local line_type, content = get_line_info(line)
        table.insert(new_lines, content)
        line_types[i - 1] = line_type -- Store as 0-indexed
    end

    vim.bo[bufnr].modifiable = true
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, new_lines)
    vim.bo[bufnr].modifiable = false

    return line_types
end

---Apply treesitter highlighting to a diff hunk
---@param bufnr integer
---@param hunk trunks.DiffHunk
local function highlight_hunk(bufnr, hunk)
    local lines = vim.api.nvim_buf_get_lines(bufnr, hunk.start_line, hunk.end_line + 1, false)
    if #lines == 0 then
        return
    end

    local code_text = table.concat(lines, "\n")

    local ok, parser = pcall(vim.treesitter.get_string_parser, code_text, hunk.filetype)
    if not ok or not parser then
        return
    end

    local trees = parser:parse()
    if not trees or #trees == 0 then
        return
    end

    local tree = trees[1]
    if not tree then
        return
    end

    local ok_query, query = pcall(vim.treesitter.query.get, hunk.filetype, "highlights")
    if not ok_query or not query then
        return
    end

    local ns = vim.api.nvim_create_namespace("trunks_diff_syntax_" .. hunk.filetype)

    -- Apply highlights
    for id, node, _ in query:iter_captures(tree:root(), code_text) do
        local capture_name = query.captures[id]
        local start_row, start_col, end_row, end_col = node:range()

        -- Adjust row to account for buffer offset
        local buf_start_row = hunk.start_line + start_row
        local buf_end_row = hunk.start_line + end_row

        local hl_group = "@" .. capture_name .. "." .. hunk.filetype

        -- Apply highlight with priority higher than diff line backgrounds
        pcall(vim.api.nvim_buf_set_extmark, bufnr, ns, buf_start_row, start_col, {
            end_row = buf_end_row,
            end_col = end_col,
            hl_group = hl_group,
            priority = 110,
        })
    end
end

---Apply diff line background highlighting
---@param bufnr integer
---@param line_types table<integer, "added"|"removed"|"context"|"other">
local function apply_diff_line_highlighting(bufnr, line_types)
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local ns = vim.api.nvim_create_namespace("trunks_diff_lines")

    for i, line in ipairs(lines) do
        local line_idx = i - 1
        local line_type = line_types[line_idx]

        if line_type == "added" then
            -- Green background for added lines
            pcall(vim.api.nvim_buf_set_extmark, bufnr, ns, line_idx, 0, {
                end_col = #line,
                hl_group = "DiffAdd",
                priority = 100,
            })
        elseif line_type == "removed" then
            -- Red background for removed lines
            pcall(vim.api.nvim_buf_set_extmark, bufnr, ns, line_idx, 0, {
                end_col = #line,
                hl_group = "DiffDelete",
                priority = 100,
            })
        elseif line:match("^@@") then
            -- Hunk header - highlight this
            pcall(vim.api.nvim_buf_set_extmark, bufnr, ns, line_idx, 0, {
                end_col = #line,
                hl_group = "DiffChange",
                priority = 150, -- Highest priority
            })
        end
    end
end

---@param bufnr integer
function M.apply_syntax(bufnr)
    if not vim.api.nvim_buf_is_valid(bufnr) then
        return
    end

    -- Strip diff markers and get line types
    local line_types = strip_diff_markers_from_buffer(bufnr)

    apply_diff_line_highlighting(bufnr, line_types)
    local hunks = parse_diff_hunks(bufnr)

    for _, hunk in ipairs(hunks) do
        pcall(highlight_hunk, bufnr, hunk)
    end
end

return M
