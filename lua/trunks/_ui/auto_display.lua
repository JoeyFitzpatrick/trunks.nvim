---@class trunks.AutoDisplayOpts
---@field generate_cmd fun(bufnr: integer): string?
---@field get_current_diff fun(bufnr: integer): string?
---@field strategy trunks.Strategy

local M = {}

---@class trunks.AutoDisplayState
---@field diff_bufnr integer
---@field diff_win integer
---@field current_diff string
---@field show_auto_display boolean
---@field suppress_next_render boolean

---@param bufnr integer
---@return trunks.AutoDisplayState
local function get_state(bufnr)
    if not vim.api.nvim_buf_is_valid(bufnr) then
        return nil
    end
    return vim.b[bufnr].trunks_auto_display_state
end

---@param bufnr integer
---@param state table<string, any>
local function set_state(bufnr, state)
    vim.b[bufnr].trunks_auto_display_state = vim.tbl_extend("force", vim.b[bufnr].trunks_auto_display_state, state)
end

---@param bufnr integer
function M.close_auto_display(bufnr)
    local state = get_state(bufnr)
    if state.diff_bufnr and vim.api.nvim_buf_is_valid(state.diff_bufnr) then
        vim.api.nvim_buf_delete(state.diff_bufnr, { force = true })
    end
    vim.b[bufnr].trunks_auto_display_state = { show_auto_display = state.show_auto_display }
end

function M.close_open_auto_displays()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf) and vim.b[buf].trunks_auto_display_state then
            M.close_auto_display(buf)
            -- Set flag to suppress the next scheduled render
            set_state(buf, { suppress_next_render = true })
        end
    end
end

---@param diff_bufnr integer
---@param original_bufnr integer
---@param win integer
local function set_diff_buffer_autocmds(diff_bufnr, original_bufnr, win)
    vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
        desc = "Stop insert mode on buf enter",
        buffer = diff_bufnr,
        command = "stopinsert",
        group = vim.api.nvim_create_augroup("TrunksAutoDisplayStopInsert", { clear = true }),
    })
    vim.api.nvim_create_autocmd("BufUnload", {
        desc = "Close open diffs and clean up diff variables",
        buffer = original_bufnr,
        callback = function()
            M.close_auto_display(original_bufnr)
            require("trunks._core.register").deregister_buffer(diff_bufnr, { delete_win_buffers = false })
        end,
        group = vim.api.nvim_create_augroup("TrunksCloseAutoDisplay", { clear = true }),
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
        group = vim.api.nvim_create_augroup("TrunksHideAutoDisplay", { clear = true }),
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
function M._render_auto_display(bufnr, auto_display_opts)
    if not vim.api.nvim_buf_is_valid(bufnr) then
        return
    end
    local state = get_state(bufnr)

    local current_diff = auto_display_opts.get_current_diff(bufnr)
    if not current_diff then
        M.close_auto_display(bufnr)
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
    if state.diff_bufnr and vim.api.nvim_buf_is_valid(state.diff_bufnr) then
        vim.api.nvim_buf_delete(state.diff_bufnr, { force = true })
    end
    state.diff_bufnr = require("trunks._ui.elements").new_buffer({})
    local win = vim.api.nvim_get_current_win()
    vim.wo[win].number = false
    vim.wo[win].relativenumber = false
    local term = require("trunks._ui.elements").terminal(state.diff_bufnr, diff_cmd, auto_display_opts.strategy)
    state.diff_win = term.win
    set_diff_buffer_autocmds(state.diff_bufnr, bufnr, win)
    set_diff_buffer_keymaps(state.diff_bufnr, bufnr)
    vim.api.nvim_set_current_win(win)
    vim.b[bufnr].trunks_auto_display_state = state
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
            local state = get_state(bufnr)
            if not state.show_auto_display then
                return
            end
            -- We want to wait here, because if this is called while closing another window,
            -- An error is thrown. This way, we wait until that close happens (if one does happen).
            vim.schedule(function()
                local current_state = get_state(bufnr)
                if not current_state then
                    return
                end
                -- Check if rendering should be suppressed (e.g., after closing from popup action)
                if current_state.suppress_next_render then
                    set_state(bufnr, { suppress_next_render = false })
                    return
                end
                M._render_auto_display(bufnr, auto_display_opts)
            end)
        end,
        group = vim.api.nvim_create_augroup("TrunksShowAutoDisplay", { clear = true }),
    })
end

---@param bufnr integer
---@param auto_display_opts trunks.AutoDisplayOpts
local function set_keymaps(bufnr, auto_display_opts)
    local keymap_opts = { noremap = true, silent = true, buffer = bufnr, nowait = true }
    local set = require("trunks._ui.keymaps.set").safe_set_keymap
    local keymaps = require("trunks._core.configuration").DATA.auto_display.keymaps
    if not keymaps then
        return nil
    end

    set("n", keymaps.toggle_auto_display, function()
        local state = get_state(bufnr)
        if not state.show_auto_display then
            set_state(bufnr, { show_auto_display = true })
            M._render_auto_display(bufnr, auto_display_opts)
        else
            set_state(bufnr, { show_auto_display = false })
            M.close_auto_display(bufnr)
        end
    end, keymap_opts)

    set("n", keymaps.scroll_diff_down, function()
        local state = vim.b[bufnr].trunks_auto_display_state
        if state.diff_bufnr and state.diff_win then
            vim.api.nvim_win_call(state.diff_win, function()
                local win_height = vim.api.nvim_win_get_height(0)
                local num_lines_in_buffer = vim.api.nvim_buf_line_count(state.diff_bufnr)
                local win_view = vim.fn.winsaveview()
                local is_at_last_line = win_view.topline > num_lines_in_buffer - win_height
                if not is_at_last_line then
                    win_view.topline = win_view.topline + 2
                    vim.fn.winrestview(win_view)
                end
            end)
        end
    end, keymap_opts)

    set("n", keymaps.scroll_diff_up, function()
        local state = vim.b[bufnr].trunks_auto_display_state
        if state.diff_bufnr and state.diff_win then
            vim.api.nvim_win_call(state.diff_win, function()
                local win_view = vim.fn.winsaveview()
                win_view.topline = win_view.topline - 2
                vim.fn.winrestview(win_view)
            end)
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

    vim.b[bufnr].trunks_auto_display_state = {
        show_auto_display = result.open_auto_display,
        suppress_next_render = false,
    }
    opts.set_keymaps(bufnr, opts.auto_display_opts)
    opts.set_autocmds(bufnr, opts.auto_display_opts)

    return result
end

--- Create an auto_display for the given buffer.
---@param bufnr integer
---@param ui_type string
---@param auto_display_opts trunks.AutoDisplayOpts
function M.create_auto_display(bufnr, ui_type, auto_display_opts)
    ---@type trunks.SetupAutoDisplayOpts
    local setup_auto_display_opts = {
        set_keymaps = set_keymaps,
        set_autocmds = set_autocmds,
        auto_display_config = require("trunks._core.configuration").DATA[ui_type],
        auto_display_opts = auto_display_opts,
    }
    local result = M._setup_auto_display(bufnr, setup_auto_display_opts)
    if result.open_auto_display then
        M._render_auto_display(bufnr, auto_display_opts)
    end
end

return M
