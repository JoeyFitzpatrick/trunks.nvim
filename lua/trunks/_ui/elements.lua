---@alias trunks.ElementType "terminal" | "home"

---@class trunks.ElementNewBufferOpts
---@field filetype? string
---@field lines? fun(bufnr?: integer): string[]
---@field win_config? vim.api.keyset.win_config
---@field enter? boolean
---@field buffer_name? string
---@field show? boolean

local M = {}

---@class trunks.BufferVariableParams
---@field bufnr integer
---@field win integer
---@field current_bufnr? integer

--- This sets up buffer local variables, so that when an Trunks buffer is closed,
--- we can navigate back to the last non-Trunks buffer, and close all Trunks
--- buffers associated with the current window.
---@param params trunks.BufferVariableParams
local function set_trunks_buffer_variables(params)
    local bufnr = params.bufnr
    local win = params.win
    local current_bufnr = params.current_bufnr
    vim.b[bufnr].is_trunks_buffer = true
    vim.b[bufnr].trunks_buffer_window_id = win

    if current_bufnr and not vim.b[current_bufnr].is_trunks_buffer then
        require("trunks._core.register").last_non_trunks_buffer_for_win[win] = current_bufnr
    end
end

local esc = string.char(27)
M.term_controls = {
    go_home = function(chan_id)
        pcall(vim.api.nvim_chan_send, chan_id, esc .. "[H")
    end,
    clear_from_cursor = function(chan_id)
        pcall(vim.api.nvim_chan_send, chan_id, esc .. "[J")
    end,
    clear_to_end_of_line = function(chan_id)
        pcall(vim.api.nvim_chan_send, chan_id, esc .. "[K")
    end,
    add_line = function(chan_id, line)
        pcall(function()
            vim.api.nvim_chan_send(chan_id, line)
            vim.api.nvim_chan_send(chan_id, esc .. "[K")
            vim.api.nvim_chan_send(chan_id, "\r\n")
        end)
    end,
}

local function get_current_ui_opts()
    return {
        number = vim.o.number,
        relativenumber = vim.o.relativenumber,
        signcolumn = vim.o.signcolumn,
    }
end

---@class trunks.TerminalOpts
---@field on_exit? fun(exit_code: integer)

---@param cmd string
---@param bufnr integer
---@param strategy trunks.Strategy
---@param opts trunks.TerminalOpts
---@return { channel_id: integer, exit_code: integer }
function M._run_terminal_command(cmd, bufnr, strategy, opts)
    local current_buffer_name = vim.api.nvim_buf_get_name(bufnr)
    local current_ui_opts = get_current_ui_opts()

    local channel_id
    local term_exit_code
    vim.bo[bufnr].modified = false
    vim.api.nvim_buf_call(bufnr, function()
        local jobstart_opts = {
            term = true,
            on_exit = function(_, exit_code, _)
                term_exit_code = exit_code
                if opts.on_exit then
                    opts.on_exit(exit_code)
                end

                if strategy.trigger_redraw then
                    require("trunks._core.register").rerender_buffers()
                end
            end,
        }
        -- Make any editor git spawns from this terminal (commit message, rebase
        -- todo, etc.) open in this instance instead of a nested Nvim.
        jobstart_opts.env = require("trunks._core.nested-buffers").editor_job_env()
        channel_id = vim.fn.jobstart(cmd, jobstart_opts)
        for opt, value in pairs(current_ui_opts) do
            vim.o[opt] = value
        end
        if current_buffer_name then
            vim.api.nvim_buf_set_name(bufnr, current_buffer_name)
        end
    end)
    vim.b[bufnr].trunks_channel_id = channel_id
    return { channel_id = channel_id, exit_code = term_exit_code }
end

---@param cmd string
---@param bufnr integer
---@param strategy trunks.Strategy
---@param opts trunks.TerminalOpts
---@return { win: integer, channel_id: integer, exit_code: integer }
function M._open_terminal_buffer(cmd, bufnr, strategy, opts)
    vim.bo[bufnr].scrollback = 1000000 -- Max scrollback as of this writing
    local run_command_result = M._run_terminal_command(cmd, bufnr, strategy, opts)

    local strategies = require("trunks._constants.command_strategies").STRATEGIES
    local display_strategy = strategy.display_strategy
    local win = vim.api.nvim_get_current_win()

    local mods = ""
    if strategy.input_args then
        mods = strategy.input_args.mods
    end

    local should_split = vim.tbl_contains({ "above", "below", "right", "left" }, display_strategy) or mods ~= ""
    if should_split then
        local enter = true
        if strategy.enter == false then
            enter = false
        end
        -- Cast this to appease type checker
        ---@cast display_strategy "above" | "below" | "right" | "left"
        vim.cmd(mods .. " split")
        win = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(win, bufnr)
        if not enter then
            vim.cmd("wincmd p")
        end
    elseif display_strategy == strategies.FULL then
        vim.api.nvim_win_set_buf(0, bufnr)
    else
        error("Unable to determine display strategy", vim.log.levels.ERROR)
    end
    return { win = win, channel_id = run_command_result.channel_id, exit_code = run_command_result.exit_code }
end

---@param cmd string
---@param bufnr integer
---@param strategy trunks.Strategy
local function set_terminal_autocmds_and_state(cmd, bufnr, strategy)
    if strategy.trigger_redraw then
        local augroup = vim.api.nvim_create_augroup("TrunksTerminalReloadBuffers", { clear = true })
        vim.api.nvim_create_autocmd({ "BufLeave" }, {
            buffer = bufnr,
            group = augroup,
            command = "checktime",
        })
    end
    if not strategy.trigger_redraw then
        vim.b[bufnr].trunks_rerender_fn = function()
            local win = vim.fn.bufwinid(bufnr)
            if not vim.api.nvim_win_is_valid(win) then
                return
            end
            local cursor = vim.api.nvim_win_get_cursor(win)
            local line_num = cursor[1]
            require("trunks._ui.utils.buffer_text").set(bufnr, {})
            M._run_terminal_command(cmd, bufnr, strategy, {})
            vim.wait(200, function()
                return vim.api.nvim_buf_line_count(bufnr) >= line_num
            end, 200)
            pcall(vim.api.nvim_win_set_cursor, win, cursor)
            if not strategy.insert then
                vim.cmd("stopinsert")
            end
        end
    end
end

---@param bufnr integer
---@param cmd string
---@param strategy trunks.Strategy
---@param opts? trunks.TerminalOpts
---@return { bufnr: integer, win: integer, chan: integer, exit_code: integer } | nil
function M.terminal(bufnr, cmd, strategy, opts)
    opts = opts or {}
    require("trunks._ui.auto_display").close_open_auto_displays()

    strategy = require("trunks._constants.command_strategies").get_strategy(cmd, strategy)

    local open_term_result = M._open_terminal_buffer(cmd, bufnr, strategy, opts)
    local win = open_term_result.win
    local channel_id = open_term_result.channel_id
    if not channel_id then
        return
    end

    if strategy.tail then
        vim.cmd("$")
    end
    if strategy.insert then
        vim.cmd("startinsert")
    else
        vim.cmd("stopinsert")
    end

    set_trunks_buffer_variables({ bufnr = bufnr, win = win })
    require("trunks._ui.keymaps.base").set_keymaps(bufnr)
    set_terminal_autocmds_and_state(cmd, bufnr, strategy)
    return { bufnr = bufnr, win = win, chan = channel_id, exit_code = open_term_result.exit_code }
end

---@param bufnr integer
---@param float_opts? vim.api.keyset.win_config
---@return integer -- win id
function M.float(bufnr, float_opts)
    local width = math.floor(vim.o.columns * 0.8)
    local height = math.floor(vim.o.lines * 0.8)
    local col = math.floor((vim.o.columns - width) / 2)
    local row = math.floor((vim.o.lines - height) / 2)

    ---@type vim.api.keyset.win_config
    local default_float_opts = {
        relative = "editor",
        width = width,
        height = height,
        col = col,
        row = row,
        style = "minimal",
        border = "rounded",
    }
    float_opts = vim.tbl_extend("force", default_float_opts, float_opts or {})
    local win = vim.api.nvim_open_win(bufnr, true, float_opts)
    return win
end

---@param opts trunks.ElementNewBufferOpts -- opts for new buffer
---@return integer, integer -- buffer id, window id
function M.new_buffer(opts)
    local bufnr = vim.api.nvim_create_buf(false, true)
    require("trunks._ui.keymaps.set").set_q_keymap(bufnr)
    local win

    if opts.win_config then
        local enter = true
        if opts.enter == false then
            enter = false
        end
        win = vim.api.nvim_open_win(bufnr, enter, opts.win_config)
    else
        win = vim.api.nvim_get_current_win()
        local current_buf = vim.api.nvim_get_current_buf()
        if opts.show then
            vim.api.nvim_win_set_buf(win, bufnr)
        end
        set_trunks_buffer_variables({ bufnr = bufnr, win = win, current_bufnr = current_buf })
    end

    if opts.filetype then
        vim.api.nvim_set_option_value("filetype", opts.filetype, { buf = bufnr })
    end

    local moved_to_existing_buffer = false
    if opts.buffer_name then
        local ok = pcall(vim.api.nvim_buf_set_name, bufnr, opts.buffer_name)
        if not ok then
            vim.cmd("e " .. opts.buffer_name)
            moved_to_existing_buffer = true
        end
    end

    if opts.lines and not moved_to_existing_buffer then
        vim.bo[bufnr].modifiable = true
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, opts.lines(bufnr))
    end
    vim.bo[bufnr].modifiable = false

    return bufnr, win
end

return M
