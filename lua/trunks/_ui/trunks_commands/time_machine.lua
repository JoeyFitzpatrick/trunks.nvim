---@class trunks.TimeMachineCacheEntry
---@field hash string
---@field filename string
---@field rename_filename? string

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
    M.cache[filename] = {}

    local current_commit = nil
    local current_filename = filename

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
                    if current_commit then
                        local cache_data = { hash = current_commit, filename = current_filename }

                        local file_was_renamed = vim.startswith(line, "R")
                        local rename_filename
                        if file_was_renamed then
                            rename_filename = line:match("%s(%S+)")
                            cache_data.rename_filename = rename_filename
                        end

                        table.insert(M.cache[filename], cache_data)
                        current_commit = nil

                        if file_was_renamed then
                            current_filename = rename_filename
                        end
                    end
                end
            end
        end,
    })
end

---@param filename string
---@param index integer
---@return string, string? -- filename to use, and optional rename filename
local function get_cache_filename(filename, index)
    if M.cache[filename] and M.cache[filename][index] and M.cache[filename][index].filename then
        return M.cache[filename][index].filename, M.cache[filename][index].rename_filename
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

---@param old_bufnr integer
---@param commit? string
local function time_machine_split(old_bufnr, commit)
    local win = vim.api.nvim_get_current_win()
    if commit then
        vim.cmd("Trunks vdiff " .. commit .. "^")
    else
        vim.cmd("Trunks vdiff")
    end

    local new_bufnr = vim.api.nvim_get_current_buf()
    vim.b[old_bufnr].time_machine_split_args =
        { bufnr = new_bufnr, split_type = commit and "previous_commit" or "HEAD" }
    vim.api.nvim_set_current_win(win)

    vim.api.nvim_create_autocmd({ "BufUnload", "BufWipeout", "BufHidden" }, {
        buffer = new_bufnr,
        callback = function()
            vim.b[old_bufnr].time_machine_split_args = nil
        end,
        group = vim.api.nvim_create_augroup("TrunksRemoveTimeMachineSplitVars", { clear = true }),
    })
end

---@param bufnr integer
local function set_file_keymaps(bufnr)
    local time_machine_keymaps = require("trunks._ui.keymaps.base").get_keymaps(bufnr, "time_machine", {})
    local time_machine_file_keymaps = require("trunks._ui.keymaps.base").get_keymaps(bufnr, "time_machine_file", {})
    local keymaps = vim.tbl_extend("force", time_machine_keymaps, time_machine_file_keymaps)

    local keymap_opts = { buffer = bufnr, nowait = true }
    local safe_set_keymap = require("trunks._ui.keymaps.set").safe_set_keymap

    safe_set_keymap("n", keymaps.commit_details, function()
        local commit = vim.b.commit
        if commit then
            require("trunks._ui.commit_details").render(commit, {})
        end
    end, keymap_opts)

    safe_set_keymap("n", keymaps.diff_against_previous_commit, function()
        local commit = vim.b.commit
        if commit then
            time_machine_split(bufnr, commit)
        end
    end, keymap_opts)

    safe_set_keymap("n", keymaps.diff_against_head, function()
        time_machine_split(bufnr)
    end, keymap_opts)

    safe_set_keymap("n", keymaps.next, function()
        vim.cmd("Trunks time-machine-next")
    end, keymap_opts)

    safe_set_keymap("n", keymaps.previous, function()
        vim.cmd("Trunks time-machine-previous")
    end, keymap_opts)

    safe_set_keymap("n", "q", function()
        require("trunks._core.register").deregister_buffer(bufnr, {})
        local num_tabs = #vim.api.nvim_list_tabpages()
        if num_tabs > 1 then
            vim.cmd.tabclose()
        end
    end, keymap_opts)
end

---@param bufnr integer
---@param filename string
---@param open_type "tab" | "window" | "vertical" | "horizontal"
---@return integer | nil -- Bufnr of opened file
local function open_file(bufnr, filename, open_type)
    local ok, line_data = pcall(M._get_line, bufnr)
    if not ok or not line_data then
        return
    end

    if not M.cache[filename] or not M.cache[filename][line_data.time_machine_index] then
        return
    end

    local time_machine_data = M.cache[filename][line_data.time_machine_index]
    local file = time_machine_data.filename
    local hash = time_machine_data.hash

    local new_bufnr
    if open_type == "tab" then
        new_bufnr = require("trunks._core.open_file").open_file_in_tab(file, hash, { original_filename = filename })
    elseif open_type == "window" then
        new_bufnr =
            require("trunks._core.open_file").open_file_in_current_window(file, hash, { original_filename = filename })
    elseif open_type == "vertical" then
        require("trunks._ui.auto_display").close_auto_display(bufnr, "time_machine")
        new_bufnr =
            require("trunks._core.open_file").open_file_in_split(file, hash, "right", { original_filename = filename })
    elseif open_type == "horizontal" then
        require("trunks._ui.auto_display").close_auto_display(bufnr, "time_machine")
        new_bufnr =
            require("trunks._core.open_file").open_file_in_split(file, hash, "below", { original_filename = filename })
    end

    set_file_keymaps(vim.api.nvim_get_current_buf())

    vim.b.time_machine_index = line_data.time_machine_index
    vim.b.original_filename = filename
    return new_bufnr
end

---@param bufnr integer
---@param filename string
local function set_keymaps(bufnr, filename)
    local keymaps = require("trunks._ui.keymaps.base").get_keymaps(bufnr, "time_machine", { open_file_keymaps = true })
    local keymap_opts = { buffer = bufnr, nowait = true }
    local safe_set_keymap = require("trunks._ui.keymaps.set").safe_set_keymap

    safe_set_keymap("n", keymaps.open_in_current_window, function()
        open_file(bufnr, filename, "window")
    end, keymap_opts)

    safe_set_keymap("n", keymaps.open_in_horizontal_split, function()
        open_file(bufnr, filename, "horizontal")
    end, keymap_opts)

    safe_set_keymap("n", keymaps.open_in_new_tab, function()
        open_file(bufnr, filename, "tab")
    end, keymap_opts)

    safe_set_keymap("n", keymaps.open_in_vertical_split, function()
        open_file(bufnr, filename, "vertical")
    end, keymap_opts)

    safe_set_keymap("n", keymaps.commit_details, function()
        local ok, line_data = pcall(M._get_line, bufnr)
        if not ok or not line_data then
            return
        end
        require("trunks._ui.commit_details").render(line_data.hash, {})
    end, keymap_opts)

    safe_set_keymap("n", keymaps.diff_against_previous_commit, function()
        local ok, line_data = pcall(M._get_line, bufnr)
        if not ok or not line_data then
            return
        end

        open_file(bufnr, filename, "window")
        vim.cmd("Trunks vdiff " .. line_data.hash .. "^")
    end, keymap_opts)

    safe_set_keymap("n", keymaps.diff_against_head, function()
        local ok, line_data = pcall(M._get_line, bufnr)
        if not ok or not line_data then
            return
        end

        open_file(bufnr, filename, "window")
        vim.cmd("Trunks vdiff")
    end, keymap_opts)

    safe_set_keymap("n", "q", function()
        require("trunks._core.register").deregister_buffer(bufnr, {})
        vim.cmd.tabclose()
    end, keymap_opts)
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
            local filename_to_use, rename_filename = get_cache_filename(filename, line_data.time_machine_index)

            local diff_command_builder = Command.base_command(
                string.format("show %s -- %s", line_data.hash, vim.fn.shellescape(filename_to_use))
            )

            if rename_filename then
                diff_command_builder = Command.base_command(
                    string.format(
                        "show %s --diff-filter=R --format= -- %s %s",
                        line_data.hash,
                        vim.fn.shellescape(filename_to_use),
                        vim.fn.shellescape(rename_filename)
                    )
                )
            end

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
---@param direction "next" | "previous"
local function move_through_time_machine(bufnr, direction)
    local filename = vim.b[bufnr].original_filename or vim.fn.expand("%")
    cache_commits_with_filename(filename)

    local time_machine_index = vim.b[bufnr].time_machine_index
    if not time_machine_index then
        -- If using `next` from most recent revision, no-op
        if direction == "next" then
            vim.notify("Can't run time-machine-next, already at most recent revision", vim.log.levels.INFO)
            return
        elseif direction == "previous" then
            time_machine_index = 0
        end
    end

    if direction == "next" then
        time_machine_index = time_machine_index - 1
    elseif direction == "previous" then
        time_machine_index = time_machine_index + 1
    end

    local time_machine_data = M.cache[filename][time_machine_index]

    if not time_machine_data then
        -- Cache might not have values yet; wait a moment and retry
        vim.cmd("sleep 50m")
        time_machine_data = M.cache[filename][time_machine_index]
    end

    vim.b[bufnr].commit = time_machine_data.hash

    local winview = vim.fn.winsaveview()
    local split_args = vim.b[bufnr].time_machine_split_args

    local new_bufnr = require("trunks._core.open_file").open_file_in_current_window(
        time_machine_data.filename,
        time_machine_data.hash,
        { original_filename = filename }
    )

    vim.b[new_bufnr].time_machine_index = time_machine_index
    vim.b[new_bufnr].original_filename = filename

    if split_args then
        require("trunks._core.register").deregister_buffer(split_args.bufnr, { delete_win_buffers = false })
        local split_commit = nil
        if split_args.split_type == "previous_commit" then
            split_commit = time_machine_data.hash
        end
        -- This relies on new_bufnr buffer variables to be set first
        time_machine_split(new_bufnr, split_commit)
    end

    set_file_keymaps(new_bufnr)
    vim.fn.winrestview(winview)
end

---@param bufnr integer
function M.previous(bufnr)
    move_through_time_machine(bufnr, "previous")
end

---@param bufnr integer
function M.next(bufnr)
    move_through_time_machine(bufnr, "next")
end

return M
