---@alias trunks.ElementType "terminal" | "home"

---@class trunks.ElementNewBufferOpts
---@field filetype? string
---@field lines? fun(bufnr?: integer): string[]
---@field win_config? vim.api.keyset.win_config
---@field enter? boolean
---@field buffer_name? string
---@field show? boolean

local M = {}

local esc = string.char(27)

M._pty_on_stdout = function(channel_id)
    vim.api.nvim_chan_send(channel_id, esc .. "[H") -- go home
    local is_first_line = true
    return function(_, data, _)
        for _, line in ipairs(data) do
            if line ~= "" then
                if not is_first_line then
                    line = "\r\n" .. line
                else
                    is_first_line = false
                end
                -- Strip trailing carriage returns to ensure cursor is at end of line before clearing
                line = line:gsub("\r+$", "")
                line = line .. esc .. "[K" -- delete from cursor to end of line
                local ok = pcall(vim.api.nvim_chan_send, channel_id, line)
                if not ok then
                    return
                end
            end
        end
        pcall(vim.api.nvim_chan_send, channel_id, esc .. "[J") -- clear from cursor
    end
end

---@param cmd string
---@param bufnr integer
---@param strategy trunks.Strategy
---@return { channel_id: integer, exit_code: integer }
local function run_terminal_command(cmd, bufnr, strategy)
    local channel_id
    if strategy.pty then
        channel_id = vim.b[bufnr].channel_id or vim.api.nvim_open_term(bufnr, {})
    end
    vim.b[bufnr].channel_id = channel_id

    local on_stdout = nil
    if strategy.pty then
        vim.api.nvim_chan_send(channel_id, esc .. "[H") -- go home
        on_stdout = M._pty_on_stdout(channel_id)
    end

    local new_channel_id
    local term_exit_code
    vim.api.nvim_buf_call(bufnr, function()
        new_channel_id = vim.fn.jobstart(cmd, {
            pty = strategy.pty,
            term = not strategy.pty,
            -- No on_stderr needed, it's merged with stdout when pty = true
            on_stdout = on_stdout,
            on_exit = function(_, exit_code, _)
                term_exit_code = exit_code

                if strategy.trigger_redraw then
                    require("trunks._core.register").rerender_buffers()
                end
            end,
        })
    end)
    return { channel_id = channel_id or new_channel_id, exit_code = term_exit_code }
end

---@param cmd string
---@param bufnr integer
---@param strategy trunks.Strategy
---@return { win: integer, channel_id: integer, exit_code: integer }
local function open_terminal_buffer(cmd, bufnr, strategy)
    vim.bo[bufnr].scrollback = 1000000
    local run_command_result = run_terminal_command(cmd, bufnr, strategy)

    local strategies = require("trunks._constants.command_strategies").STRATEGIES
    local display_strategy = strategy.display_strategy
    local win = vim.api.nvim_get_current_win()
    if vim.tbl_contains({ "above", "below", "right", "left" }, display_strategy) then
        local enter = true
        if strategy.enter == false then
            enter = false
        end
        -- Cast this to appease type checker
        ---@cast display_strategy "above" | "below" | "right" | "left"
        if strategy.win_size then
            if vim.tbl_contains({ "above", "below" }, display_strategy) then
                local height = math.floor(vim.o.lines * strategy.win_size)
                win = vim.api.nvim_open_win(bufnr, enter, { split = display_strategy, height = height })
            else
                local width = math.floor(vim.o.columns * strategy.win_size)
                win = vim.api.nvim_open_win(bufnr, enter, { split = display_strategy, width = width })
            end
        else
            -- Use golden ratio for above/below splits to create smaller split
            if vim.tbl_contains({ "above", "below" }, display_strategy) then
                local current_win_height = vim.api.nvim_win_get_height(win)
                local golden_ratio = (1 + math.sqrt(5)) / 2
                local height = math.floor(current_win_height / (1 + golden_ratio))
                win = vim.api.nvim_open_win(bufnr, enter, { split = display_strategy, height = height })
            else
                win = vim.api.nvim_open_win(bufnr, enter, { split = display_strategy })
            end
        end
    elseif display_strategy == strategies.FULL then
        vim.api.nvim_win_set_buf(0, bufnr)
    else
        error("Unable to determine display strategy", vim.log.levels.ERROR)
    end
    vim.opt_local.number = false
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
    if strategy.pty and not strategy.trigger_redraw then
        vim.b[bufnr].trunks_rerender_fn = function()
            run_terminal_command(cmd, bufnr, strategy)
        end
    end
end

---@param bufnr integer
---@param cmd string
---@param strategy? trunks.Strategy
---@return { bufnr: integer, win: integer, chan: integer, exit_code: integer } | nil
function M.terminal(bufnr, cmd, strategy)
    require("trunks._ui.auto_display").close_open_auto_displays()
    -- Buffer local variable that makes any editors opened from this terminal,
    -- such as the commit editor, use the current nvim instance instead of a nested one.
    vim.b[bufnr].trunks_use_nested_nvim = true

    strategy = require("trunks._constants.command_strategies").get_strategy(cmd, strategy)

    local open_term_result = open_terminal_buffer(cmd, bufnr, strategy)
    local win = open_term_result.win
    local channel_id = open_term_result.channel_id
    local exit_code = open_term_result.exit_code
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

    require("trunks._ui.keymaps.base").set_keymaps(bufnr, { terminal_channel_id = channel_id })
    set_terminal_autocmds_and_state(cmd, bufnr, strategy)
    return { bufnr = bufnr, win = win, chan = channel_id, exit_code = exit_code }
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

--- This sets up buffer local variables, so that when an Trunks buffer is closed,
--- we can navigate back to the last non-Trunks buffer, and close all Trunks
--- buffers associated with the current window.
---@param current_buf integer
---@param new_buf integer
---@param win integer
local function setup_last_non_trunks_buffer(current_buf, new_buf, win)
    vim.b[new_buf].is_trunks_buffer = true

    if not vim.b[current_buf].is_trunks_buffer then
        require("trunks._core.register").last_non_trunks_buffer_for_win[win] = current_buf
    end
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
        setup_last_non_trunks_buffer(current_buf, bufnr, win)
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
