---@class trunks.AutoDisplayOpts
---@field generate_cmd fun(bufnr: integer): string?
---@field get_current_diff fun(bufnr: integer): string?
---@field strategy trunks.Strategy

local M = {}

---@param bufnr integer
local function clear_state(bufnr)
    local state = vim.b[bufnr].trunks_auto_display_state
    if not state then
        return
    end
    if state.diff_bufnr and vim.api.nvim_buf_is_valid(state.diff_bufnr) then
        vim.api.nvim_buf_delete(state.diff_bufnr, { force = true })
    end
    vim.b[bufnr].trunks_auto_display_state = nil
end

---@param diff_bufnr integer
---@param original_bufnr integer
---@param win integer
---@param ui_type string
local function set_diff_buffer_autocmds(diff_bufnr, original_bufnr, win, ui_type)
    vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
        desc = "Stop insert mode on buf enter",
        buffer = diff_bufnr,
        command = "stopinsert",
        group = vim.api.nvim_create_augroup(string.format("Trunks%sStopInsert", ui_type), { clear = false }),
    })
    vim.api.nvim_create_autocmd("BufUnload", {
        desc = "Close open diffs and clean up diff variables",
        buffer = original_bufnr,
        callback = function()
            local buf = require("trunks._core.register").buffers[original_bufnr]
            if buf then
                clear_state(original_bufnr)
            end
            require("trunks._core.register").deregister_buffer(diff_bufnr, { delete_win_buffers = false })
        end,
        group = vim.api.nvim_create_augroup(string.format("Trunks%sCloseAutoDisplay", ui_type), { clear = true }),
    })
    vim.api.nvim_create_autocmd("BufHidden", {
        desc = "Close open diffs and clean up diff variables",
        buffer = original_bufnr,
        callback = function()
            vim.schedule(function()
                local diff_bufnr_win = vim.fn.bufwinid(diff_bufnr)
                if not vim.api.nvim_win_is_valid(win) or not vim.api.nvim_win_is_valid(diff_bufnr_win) then
                    return
                end
                vim.api.nvim_win_close(diff_bufnr_win, true)
            end)
        end,
        group = vim.api.nvim_create_augroup(string.format("Trunks%sHideAutoDisplay", ui_type), { clear = true }),
    })
end

---@param diff_bufnr integer
---@param original_bufnr integer
local function set_diff_buffer_keymaps(diff_bufnr, original_bufnr)
    require("trunks._ui.keymaps.set").safe_set_keymap("n", "q", function()
        require("trunks._core.register").deregister_buffer(diff_bufnr)
        require("trunks._core.register").deregister_buffer(original_bufnr)
    end, { buffer = diff_bufnr })

    require("trunks._ui.keymaps.set").safe_set_keymap("n", "<enter>", function()
        require("trunks._core.register").deregister_buffer(diff_bufnr)
    end, { buffer = diff_bufnr })
end

---@param bufnr integer
---@param auto_display_opts trunks.AutoDisplayOpts
local function render_auto_display(bufnr, auto_display_opts)
    local registered_buffer = require("trunks._core.register").buffers[bufnr]
    if not registered_buffer or not registered_buffer.state then
        return
    end
    local state = registered_buffer.state
    local current_diff = auto_display_opts.get_current_diff(bufnr)
    if not current_diff then
        clear_state(bufnr)
        return
    end
    if current_diff == state.current_diff then
        return
    end
    local diff_cmd = auto_display_opts.generate_cmd(bufnr)
    if not diff_cmd then
        return
    end
    state.current_diff = current_diff
    if state.diff_bufnr then
        if vim.api.nvim_buf_is_valid(state.diff_bufnr) then
            vim.api.nvim_buf_delete(state.diff_bufnr, { force = true })
        end
        state.diff_bufnr = nil
    end
    state.diff_bufnr = vim.api.nvim_create_buf(false, true)
    local win = vim.api.nvim_get_current_win()
    local term = require("trunks._ui.elements").terminal(state.diff_bufnr, diff_cmd, auto_display_opts.strategy)
    state.diff_channel_id = term.chan
    set_diff_buffer_autocmds(state.diff_bufnr, bufnr, win)
    set_diff_buffer_keymaps(state.diff_bufnr, bufnr)
    vim.api.nvim_set_current_win(win)
end

---@param bufnr integer
---@param auto_display_opts trunks.AutoDisplayOpts
local function set_autocmds(bufnr, auto_display_opts)
    if not vim.api.nvim_buf_is_valid(bufnr) then
        return
    end
    vim.api.nvim_create_autocmd({ "CursorMoved", "BufEnter" }, {
        desc = "Diff the file under the cursor",
        buffer = bufnr,
        callback = function()
            local state = require("trunks._core.register").buffers[bufnr].state
            if not state.display_auto_display then
                return
            end
            -- We want to wait here, because if this is called while closing another window,
            -- An error is thrown. This way, we wait until that close happens (if one does happen).
            vim.defer_fn(function()
                render_auto_display(bufnr, auto_display_opts)
            end, 10)
        end,
        group = vim.api.nvim_create_augroup("TrunksShowAutoDisplay", { clear = true }),
    })
end

---@param bufnr integer
---@param ui_type string
---@param auto_display_opts trunks.AutoDisplayOpts
local function set_keymaps(bufnr, ui_type, auto_display_opts)
    local keymap_opts = { noremap = true, silent = true, buffer = bufnr, nowait = true }
    local registered_buffer = require("trunks._core.register").buffers[bufnr]
    if not registered_buffer then
        return
    end
    local set = require("trunks._ui.keymaps.set").safe_set_keymap
    local keymaps = require("trunks._core.configuration").DATA.auto_display.keymaps
    if not keymaps then
        return nil
    end

    set("n", keymaps.toggle_auto_display, function()
        if registered_buffer.state.display_auto_display then
            clear_state(registered_buffer)
        else
            registered_buffer.state.display_auto_display = true
            render_auto_display(bufnr, ui_type, auto_display_opts)
        end
    end, keymap_opts)

    set("n", keymaps.scroll_diff_down, function()
        if registered_buffer.state.diff_bufnr and registered_buffer.state.diff_channel_id then
            pcall(vim.api.nvim_chan_send, registered_buffer.state.diff_channel_id, "jj")
        end
    end, keymap_opts)

    set("n", keymaps.scroll_diff_up, function()
        if registered_buffer.state.diff_bufnr and registered_buffer.state.diff_channel_id then
            pcall(vim.api.nvim_chan_send, registered_buffer.state.diff_channel_id, "kk")
        end
    end, keymap_opts)
end

---@class trunks.SetupAutoDisplayOpts
---@field set_keymaps fun(bufnr: integer)
---@field set_autocmds fun(bufnr: integer, opts: table)
---@field auto_display_config? table<string, any>
---@field auto_display_opts trunks.AutoDisplayOpts

---@class trunks.SetupAutoDisplayResult
---@field auto_display_on boolean
---@field display_strategy trunks.DisplayStrategy
---@field win_size integer

---@param bufnr integer
---@param opts trunks.SetupAutoDisplayOpts
function M._setup_auto_display(bufnr, opts)
    local result = {}

    local open_auto_display = vim.tbl_get(opts.auto_display_config or {}, "auto_display_on")
    if open_auto_display == false then
        result.open_auto_display = false
    else
        result.open_auto_display = true
    end

    local DEFAULT_WIN_SIZE = 0.5
    local DEFAULT_DISPLAY_STRATEGY = "below"
    result.display_strategy = opts.auto_display_opts.strategy.display_strategy or DEFAULT_DISPLAY_STRATEGY
    if opts.auto_display_opts.strategy.win_size then
        result.win_size = opts.auto_display_opts.strategy.win_size
    elseif result.display_strategy == "below" then
        result.win_size = require("trunks._constants.constants").GOLDEN_RATIO
    else
        result.win_size = DEFAULT_WIN_SIZE
    end
    opts.auto_display_opts.strategy.display_strategy = result.display_strategy
    opts.auto_display_opts.strategy.win_size = result.win_size

    opts.set_keymaps(bufnr)
    opts.set_autocmds(bufnr, opts.auto_display_opts)

    return result
end

--- Create an auto_display for the given buffer.
---@param bufnr integer
---@param ui_type string
---@param auto_display_opts trunks.AutoDisplayOpts
function M.create_auto_display(bufnr, ui_type, auto_display_opts)
    clear_state(bufnr)
    ---@type trunks.SetupAutoDisplayOpts
    local setup_auto_display_opts = {
        set_keymaps = set_keymaps,
        set_autocmds = set_autocmds,
        auto_display_config = require("trunks._core.configuration").DATA[ui_type],
        auto_display_opts = auto_display_opts,
    }
    M._setup_auto_display(bufnr, setup_auto_display_opts)
end

---@param bufnr integer
function M.close_auto_display(bufnr)
    local buf = require("trunks._core.register").buffers[bufnr]
    if not buf then
        return
    end
    clear_state(bufnr)
end

return M
