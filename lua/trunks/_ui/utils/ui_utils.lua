local M = {}

---@return integer, integer
function M.get_visual_line_nums()
    -- move back to normal mode to access most recent visual line nums
    -- this is a workaround, as 'getpos' won't return correct lines until visual mode is exited
    local back_to_n = vim.api.nvim_replace_termcodes("<esc>", true, false, true)
    vim.api.nvim_feedkeys(back_to_n, "x", false)
    local start = vim.fn.getpos("'<")[2] - 1
    local ending = vim.fn.getpos("'>")[2]
    return start, ending
end

---@param input_args vim.api.keyset.create_user_command.command_args
function M.is_visual_command(input_args)
    local mode = vim.api.nvim_get_mode().mode
    local in_visual_mode = mode:match("^v") or mode:match("^V") or mode:match(vim.keycode("^<c-v>"))
    return input_args.range == 2 or in_visual_mode
end

--- Return the text from the last visual selection.
---@return string
function M.get_visual_selection()
    local mode = vim.api.nvim_get_mode().mode
    local in_visual_mode = mode:match("^v") or mode:match("^V") or mode:match(vim.keycode("^<c-v>"))
    local text
    if in_visual_mode then
        text = vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."))
    else
        text = vim.fn.getregion(vim.fn.getpos("'<"), vim.fn.getpos("'>"))
    end
    return text[1]
end

function M.get_start_line(bufnr)
    if vim.api.nvim_buf_is_valid(bufnr) then
        return vim.b[bufnr].trunks_start_line or 0
    end
end

function M.set_start_line(bufnr, line_num)
    if vim.api.nvim_buf_is_valid(bufnr) then
        vim.b[bufnr].trunks_start_line = line_num
    end
end

return M
