---@class trunks.TimeMachineCacheEntry
---@field hash string
---@field filename string

local M = {}

local Command = require("trunks._core.command")

-- After keymap text and padding
local START_LINE = 1

---@type table<string, trunks.TimeMachineCacheEntry[]>
M.cache = {}

---@param filename string
local function cache_commits_with_filename(filename)
    if M.cache[filename] then
        return
    end

    local current_commit = nil
    local current_filename = filename
    M.cache[filename] = {}
    local get_historical_filenames_cmd = "git log --follow --name-status --oneline -- " .. filename
    vim.fn.jobstart(get_historical_filenames_cmd, {
        on_stdout = function(_, data, _)
            if not data then
                return
            end
            for _, line in ipairs(data) do
                local commit = line:match("%x%x%x%x%x%x%x")
                if commit then
                    current_commit = commit
                else
                    local file_was_renamed = vim.startswith(line, "R")
                    if file_was_renamed and current_commit then
                        current_filename = line:match("%s(%S+)")
                        table.insert(M.cache[filename], { hash = current_commit, filename = current_filename })
                        current_commit = nil
                    elseif current_commit then
                        table.insert(M.cache[filename], { hash = current_commit, filename = current_filename })
                        current_commit = nil
                    end
                end
            end
        end,
    })
end

---@param filename string
---@param index integer
---@return string
local function get_cache_filename(filename, index)
    if M.cache[filename] and M.cache[filename][index] and M.cache[filename][index].filename then
        return M.cache[filename][index].filename
    end
    return filename
end

---@param bufnr integer
---@param start_line? integer
---@param line_num? integer
---@return { hash: string, time_machine_index: integer } | nil
function M._get_line(bufnr, start_line, line_num)
    start_line = start_line or START_LINE
    line_num = line_num or vim.api.nvim_win_get_cursor(0)[1]
    if line_num <= start_line then
        return nil
    end
    local line = vim.api.nvim_buf_get_lines(bufnr, line_num - 1, line_num, false)[1]
    if not line then
        return nil
    end

    local hash = line:match("^%x+")
    if not hash then
        return nil
    end

    -- commits start on line 3, 0-indexed to line 2
    return { hash = hash, time_machine_index = line_num - 2 }
end

---@param bufnr integer
---@param filename string
local function set_keymaps(bufnr, filename)
    local keymaps = require("trunks._ui.keymaps.base").get_keymaps(bufnr, "time_machine", {})
    local safe_set_keymap = require("trunks._ui.keymaps.set").safe_set_keymap

    safe_set_keymap("n", keymaps.commit_details, function()
        local ok, line_data = pcall(M._get_line, bufnr)
        if not ok or not line_data then
            return
        end
        require("trunks._ui.commit_details").render(line_data.hash, {})
    end, { buffer = bufnr })

    safe_set_keymap("n", keymaps.diff_against_previous_commit, function()
        local ok, line_data = pcall(M._get_line, bufnr)
        if not ok or not line_data then
            return
        end

        local filename_at_commit = get_cache_filename(filename, line_data.time_machine_index)
        require("trunks._core.open_file").open_file_in_current_window(filename_at_commit, line_data.hash)
        vim.b[bufnr].time_machine_index = line_data.time_machine_index
        vim.cmd("G Vdiff " .. line_data.hash .. "^")
    end, { buffer = bufnr, nowait = true })

    safe_set_keymap("n", keymaps.diff_against_head, function()
        local ok, line_data = pcall(M._get_line, bufnr)
        if not ok or not line_data then
            return
        end

        local filename_at_commit = get_cache_filename(filename, line_data.time_machine_index)
        require("trunks._core.open_file").open_file_in_current_window(filename_at_commit, line_data.hash)
        vim.b[bufnr].time_machine_index = line_data.time_machine_index
        vim.cmd("G Vdiff")
    end, { buffer = bufnr, nowait = true })

    safe_set_keymap("n", "q", function()
        require("trunks._core.register").deregister_buffer(bufnr, {})
        vim.cmd.tabclose()
    end, { buffer = bufnr })
end

---@param filename string | nil
---@return string?, integer? -- error text and error code
function M.render(filename)
    filename = filename or vim.fn.expand("%")
    vim.cmd.tabnew()
    local bufnr =
        require("trunks._ui.elements").new_buffer({ filetype = "git", buffer_name = "TrunksTimeMachine--" .. filename })

    local command_builder = Command.base_command("log --follow " .. filename, filename)

    -- Use the same lines that the log UI uses
    require("trunks._ui.home_options.log").set_lines(
        bufnr,
        { command_builder = command_builder, ui_types = { "time_machine" } }
    )

    cache_commits_with_filename(filename)
    set_keymaps(bufnr, filename)

    require("trunks._ui.auto_display").create_auto_display(bufnr, "time_machine", {
        generate_cmd = function()
            local ok, line_data = pcall(M._get_line, bufnr)
            if not ok or not line_data then
                return
            end

            -- Use historical name if found, otherwise fall back to current filename
            local filename_to_use = get_cache_filename(filename, line_data.time_machine_index)

            local diff_command_builder = Command.base_command(
                string.format("show %s -- %s", line_data.hash, vim.fn.shellescape(filename_to_use))
            )
            return diff_command_builder:build()
        end,
        get_current_diff = function()
            local ok, line_data = pcall(M._get_line, bufnr)
            if not ok or not line_data then
                return
            end
            return line_data.hash
        end,
        strategy = { display_strategy = "below", win_size = 0.67, insert = false, enter = false },
    })
end

---@param bufnr integer
function M.previous(bufnr)
    local filename = vim.b[bufnr].original_filename or vim.fn.expand("%")

    cache_commits_with_filename(filename)
    local time_machine_index = vim.b[bufnr].time_machine_index or 1

    local time_machine_data = M.cache[filename][time_machine_index]

    if not time_machine_data then
        -- Cache might not have values yet; wait a moment and retry
        vim.cmd("sleep 50m")
        time_machine_data = M.cache[filename][time_machine_index]
    end

    vim.b[bufnr].original_filename = time_machine_data.filename
    vim.b[bufnr].commit = time_machine_data.hash

    local winview = vim.fn.winsaveview()
    local new_bufnr = require("trunks._core.open_file").open_file_in_current_window(filename, time_machine_data.hash)
    vim.b[new_bufnr].time_machine_index = time_machine_index + 1
    vim.fn.winrestview(winview)
end

return M
