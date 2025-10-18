---@class trunks.RegisterOpts
---@field render_fn? fun()
---@field state? table<string, any>
---@field win? integer

---@class trunks.RegisterOptsWithState
---@field render_fn? fun()
---@field state table<string, any>
---@field win? integer

---@class trunks.DeregisterOpts
---@field delete_win_buffers? boolean
---@field unload? boolean
---@field close_tab? boolean

local M = {}

---@type table<integer, trunks.RegisterOptsWithState>
M.buffers = {}

---@type table<integer, integer>
M.last_non_trunks_buffer_for_win = {}

---@param bufnr integer
---@param opts trunks.RegisterOpts
function M.register_buffer(bufnr, opts)
    if not opts.state then
        opts.state = {}
    end
    if not opts.win then
        opts.win = vim.api.nvim_get_current_win()
    end
    ---@diagnostic disable-next-line: assign-type-mismatch
    M.buffers[bufnr] = opts
end

---@param bufnr integer
local function navigate_to_last_non_trunks_buffer(bufnr)
    local win = vim.fn.bufwinid(bufnr)
    local no_win_found = win == -1
    if no_win_found then
        return
    end
    local buf_to_navigate_to = M.last_non_trunks_buffer_for_win[win]
    if not buf_to_navigate_to or not vim.api.nvim_buf_is_valid(buf_to_navigate_to) then
        return
    end
    vim.api.nvim_win_set_buf(win, M.last_non_trunks_buffer_for_win[win])
end

---@param win integer
local function delete_trunks_buffers_for_win(win)
    for bufnr, opts in pairs(M.buffers) do
        if opts.win == win then
            M.deregister_buffer(bufnr)
        end
    end
end

---@param bufnr? integer
---@param opts? trunks.DeregisterOpts
function M.deregister_buffer(bufnr, opts)
    if not bufnr then
        return
    end
    opts = opts or {}
    M.buffers[bufnr] = nil
    if vim.api.nvim_buf_is_valid(bufnr) then
        navigate_to_last_non_trunks_buffer(bufnr)

        if opts.delete_win_buffers ~= false then
            delete_trunks_buffers_for_win(vim.api.nvim_get_current_win())
        end
        if opts.unload then
            vim.bo[bufnr].buflisted = false
            vim.api.nvim_buf_delete(bufnr, { unload = true })
        else
            vim.api.nvim_buf_delete(bufnr, { force = true })
        end

        local buffers_for_tab = vim.fn.tabpagebuflist()
        local non_normal_buffer_types = { "nofile", "terminal" }
        local normal_buffers = vim.tbl_filter(function(buf)
            return not vim.tbl_contains(non_normal_buffer_types, vim.bo[buf].buftype)
        end, buffers_for_tab)

        local on_last_buffer = #normal_buffers <= 1
        local is_trunks_tab = vim.t.trunks_should_close_tab_on_buf_close
        local num_tabs = #vim.api.nvim_list_tabpages()

        if opts.close_tab and is_trunks_tab and on_last_buffer and num_tabs > 1 then
            vim.cmd("tabclose")
        else
            for _, buf in ipairs(normal_buffers) do
                vim.print(vim.bo[buf].buftype)
            end
        end
    end
end

---@param bufnr? integer optional buffer to rerender first
function M.rerender_buffers(bufnr)
    -- Always rerender current buffer first if one isn't passed in
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    local main_buffer = M.buffers[bufnr]
    if main_buffer and main_buffer.render_fn then
        main_buffer.render_fn()
    end
    for buf, opts in pairs(M.buffers) do
        if buf ~= bufnr and opts.render_fn then
            vim.schedule(opts.render_fn)
        end
    end
end

return M
