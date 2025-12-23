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

---@param win integer
function M._delete_trunks_buffers_for_win(win)
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.b[buf].trunks_buffer_window_id == win then
            vim.api.nvim_buf_delete(buf, { force = true })
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
    if not vim.api.nvim_buf_is_valid(bufnr) then
        return
    end

    if opts.delete_win_buffers ~= false then
        M._delete_trunks_buffers_for_win(vim.api.nvim_get_current_win())
    end

    vim.api.nvim_buf_delete(bufnr, { force = true })
end

---@param bufnr? integer optional buffer to rerender first
function M.rerender_buffers(bufnr)
    local main_buffer = M.buffers[bufnr]
    if main_buffer and main_buffer.render_fn then
        if main_buffer.win and vim.api.nvim_win_is_valid(main_buffer.win) then
            vim.api.nvim_win_call(main_buffer.win, main_buffer.render_fn)
        else
            main_buffer.render_fn()
        end
    end
    for buf, opts in pairs(M.buffers) do
        if buf ~= bufnr and opts.render_fn then
            vim.schedule(function()
                if opts.win and vim.api.nvim_win_is_valid(opts.win) then
                    vim.api.nvim_win_call(opts.win, opts.render_fn)
                else
                    opts.render_fn()
                end
            end)
        end
    end
end

return M
