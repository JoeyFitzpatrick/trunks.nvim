local M = {}

local FILENAME_PREFIX = require("trunks._constants.constants").FILENAME_PREFIX
---@type table<string, integer>
local BLAME_WINDOWS = {}

---@param bufnr integer
---@param line_num? integer
---@return { hash: string } | nil
local function get_line(bufnr, line_num)
    line_num = line_num or vim.api.nvim_win_get_cursor(0)[1]
    local line = vim.api.nvim_buf_get_lines(bufnr, line_num - 1, line_num, false)[1]
    if line == "" then
        return nil
    end
    return { hash = line:match("%w+") }
end

---@param bufnr integer
---@param filename string
local function set_keymaps(bufnr, filename)
    local keymap_opts = { noremap = true, silent = true, buffer = bufnr, nowait = true }
    local keymaps = require("trunks._ui.keymaps.base").get_keymaps(bufnr, "blame", {})
    local set = require("trunks._ui.keymaps.set").safe_set_keymap

    set("n", keymaps.checkout, function()
        local ok, line_data = pcall(get_line, bufnr)
        if not ok or not line_data then
            return
        end
        vim.api.nvim_buf_delete(bufnr, { force = true })
        vim.cmd("G checkout " .. line_data.hash)
    end, keymap_opts)

    set("n", keymaps.commit_details, function()
        local ok, line_data = pcall(get_line, bufnr)
        if not ok or not line_data then
            return
        end
        vim.api.nvim_buf_delete(bufnr, { force = true })
        require("trunks._ui.commit_details").render(line_data.hash, { filename = filename })
    end, keymap_opts)

    local function get_filepath()
        local buf_name = vim.api.nvim_buf_get_name(0)
        local start, finish = buf_name:find(FILENAME_PREFIX, 1, true)
        if start and finish then
            return buf_name:sub(finish + 1)
        end
        return vim.fn.expand("%:.")
    end

    set("n", keymaps.diff_file, function()
        local ok, line_data = pcall(get_line, bufnr)
        if not ok or not line_data then
            return
        end
        vim.api.nvim_buf_delete(bufnr, { force = true })
        vim.cmd(string.format("G show %s -- %s", line_data.hash, get_filepath()))
    end, keymap_opts)

    set("n", keymaps.reblame, function()
        local ok, line_data = pcall(get_line, bufnr)
        if not ok or not line_data then
            return
        end
        local current_cursor_line = vim.api.nvim_win_get_cursor(0)[1]
        vim.api.nvim_buf_delete(bufnr, { force = true })
        local filepath = get_filepath()
        require("trunks._ui.elements").new_buffer({
            filetype = vim.api.nvim_get_option_value("filetype", { buf = 0 }),
            lines = function()
                local output =
                    require("trunks._core.run_cmd").run_cmd(string.format("show %s:%s", line_data.hash, filepath))
                return output
            end,
            buffer_name = os.tmpname() .. "/" .. FILENAME_PREFIX .. filepath,
        })
        vim.cmd(string.format("G blame %s -- %s", line_data.hash, filepath))
        -- we don't want to set the cursor outside the new buffer's line count
        local new_cursor_line = math.min(current_cursor_line, vim.api.nvim_buf_line_count(0))
        vim.api.nvim_win_set_cursor(0, { new_cursor_line, 0 })
    end, keymap_opts)

    set("n", keymaps.return_to_original_file, function()
        local current_cursor_line = vim.api.nvim_win_get_cursor(0)[1]
        vim.api.nvim_buf_delete(bufnr, { force = true })
        while vim.api.nvim_buf_get_name(0):match(FILENAME_PREFIX) do
            vim.api.nvim_buf_delete(0, { force = true })
        end
        vim.api.nvim_win_set_cursor(0, { current_cursor_line, 0 })
    end, keymap_opts)

    set(
        "n",
        keymaps.show,
        require("trunks._ui.keymaps.base").git_show_keymap_fn(bufnr, get_line, filename),
        keymap_opts
    )
end

local function highlight_line(bufnr, line, line_num)
    local hlgroups = require("trunks._constants.highlight_groups").highlight_groups
    local first_word = line:match("%S+")
    if not first_word then
        return
    end
    local hex_obj = require("trunks._ui.highlight").commit_hash_to_hex(first_word)
    local hlgroup = hlgroups.TRUNKS_BLAME_HASH .. hex_obj.stripped_hash
    vim.cmd(string.format("highlight %s guifg=%s", hlgroup, hex_obj.hex))
    require("trunks._ui.highlight").highlight_line(bufnr, hlgroup, line_num, 1, #first_word)

    local timestamp_pattern = "%d%d%d%d/%d%d/%d%d %d%d:%d%d %a%a"
    local start_index, end_index = line:find(timestamp_pattern)
    require("trunks._ui.highlight").highlight_line(bufnr, "Function", line_num, start_index, end_index)
end

---@param bufnr integer
local function set_blame_win_width(bufnr)
    local closing_paren = string.find(vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1], ")")
    if closing_paren then
        local number_width = vim.fn.strwidth(tostring(vim.api.nvim_buf_line_count(0))) + 2
        vim.api.nvim_win_set_width(0, closing_paren + number_width)
    end
end

---@param bufnr integer
---@param command_builder trunks.Command
---@return "success" | "error"
function M.set_lines(bufnr, command_builder)
    local output, error_code = require("trunks._core.run_cmd").run_cmd(command_builder, {})
    if error_code ~= 0 then
        vim.notify(output[1], vim.log.levels.ERROR)
        vim.api.nvim_win_close(0, true)
        return "error"
    end
    local lines = {}
    vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
    for _, line in ipairs(output) do
        -- remove the filename when it is shown, e.g. when using -C flag
        local line_without_filename = line:gsub("^(%S*)%s+[^%(]*%(", "%1 (")
        table.insert(lines, line_without_filename)
    end
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
    set_blame_win_width(bufnr)
    for i, line in ipairs(lines) do
        highlight_line(bufnr, line, i - 1)
    end
    return "success"
end

---@param blame_bufnr integer
---@param file_win integer
---@param blame_buffer_name string
local function set_autocmds(blame_bufnr, file_win, blame_buffer_name)
    local previous_settings = {}
    local blame_settings = { { name = "scrollbind", value = true }, { name = "wrap", value = false } }
    for _, setting in ipairs(blame_settings) do
        table.insert(
            previous_settings,
            { name = setting.name, value = vim.api.nvim_get_option_value(setting.name, { win = file_win }) }
        )
    end

    for _, setting in ipairs(blame_settings) do
        vim.api.nvim_set_option_value(setting.name, setting.value, { win = file_win }) -- set value in file window
        vim.api.nvim_set_option_value(setting.name, setting.value, { win = 0 }) -- set value in blame window
    end
    vim.wo.number = false
    vim.wo.relativenumber = false

    vim.api.nvim_create_autocmd("BufHidden", {
        group = vim.api.nvim_create_augroup("TrunksBlameBufHidden", { clear = true }),
        buffer = blame_bufnr,
        desc = "Reset file options for blamed file",
        callback = function()
            for _, setting in ipairs(previous_settings) do
                vim.api.nvim_set_option_value(setting.name, setting.value, { win = file_win })
            end
            BLAME_WINDOWS[blame_buffer_name] = nil
        end,
    })

    vim.api.nvim_create_autocmd("WinResized", {
        group = vim.api.nvim_create_augroup("TrunksBlameWinResized", { clear = true }),
        buffer = blame_bufnr,
        desc = "Resize blame window",
        callback = function()
            set_blame_win_width(blame_bufnr)
        end,
    })
end

---@param command_builder trunks.Command
---@param filename string
---@return trunks.Command
local function get_blame_command(command_builder, filename)
    -- Add default blame args from config
    command_builder:add_args(table.concat(require("trunks._core.configuration").DATA.blame.default_cmd_args, " "))

    -- Add filename if not already given
    if not command_builder.base:match("%-%- %S+") then
        command_builder:add_postfix_args(" -- " .. filename)
    end
    return command_builder
end

---@param command_builder trunks.Command
M.render = function(command_builder)
    local TRUNKS_BLAME_PREFIX = "TrunksBlame://"
    local current_filename = vim.api.nvim_buf_get_name(0)
    if current_filename:sub(1, #TRUNKS_BLAME_PREFIX) == TRUNKS_BLAME_PREFIX then
        return
    end
    local blame_buffer_name = TRUNKS_BLAME_PREFIX .. current_filename
    local existing_blame_win = BLAME_WINDOWS[blame_buffer_name]
    if existing_blame_win then
        if vim.api.nvim_win_is_valid(existing_blame_win) then
            vim.api.nvim_set_current_win(existing_blame_win)
            return
        else
            BLAME_WINDOWS[existing_blame_win] = nil
        end
    end

    command_builder = get_blame_command(command_builder, current_filename)

    local original_win = vim.api.nvim_get_current_win()
    local original_cursor_pos = vim.api.nvim_win_get_cursor(original_win)
    local file_win_line_num = vim.fn.line("w0", original_win)
    local bufnr = require("trunks._ui.elements").new_buffer({
        win_config = { split = "left", width = math.floor(vim.o.columns * 0.33) },
        buffer_name = blame_buffer_name,
    })

    BLAME_WINDOWS[blame_buffer_name] = vim.api.nvim_get_current_win()
    local result = M.set_lines(bufnr, command_builder)

    if result ~= "success" then
        BLAME_WINDOWS[blame_buffer_name] = nil
        require("trunks._core.register").deregister_buffer(bufnr)
        return
    end

    -- get filename with current project as base
    local filename = vim.fn.fnamemodify(current_filename, ":~:.")
    set_keymaps(bufnr, filename)
    set_autocmds(bufnr, original_win, blame_buffer_name)

    local ok = pcall(function()
        local blame_win_initial_line = file_win_line_num + vim.wo[original_win].scrolloff
        vim.api.nvim_win_set_cursor(0, { blame_win_initial_line, 0 })
    end)
    if not ok then
        vim.api.nvim_win_set_cursor(0, { file_win_line_num, 0 })
    end
    -- Make the top line of the blame window the same as the original window
    vim.fn.winrestview({ topline = vim.fn.line("w0", original_win) })
    pcall(vim.api.nvim_win_set_cursor, 0, { original_cursor_pos[1], 0 })
    pcall(vim.api.nvim_win_set_cursor, original_win, original_cursor_pos)
    vim.cmd("syncbind")
end

return M
