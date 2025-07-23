local M = {}

-- After keymap text and padding
local START_LINE = 1

---@param bufnr integer
---@param start_line? integer
---@param line_num? integer
---@return { hash: string } | nil
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

    return { hash = hash }
end

---@param bufnr integer
---@param filename string
---@param filename_by_commit table<string, string>
local function set_keymaps(bufnr, filename, filename_by_commit)
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

        local filename_to_use = filename_by_commit[line_data.hash] or filename
        require("trunks._core.open_file").open_file_in_current_window(filename_to_use, line_data.hash)
        vim.cmd("G Vdiff " .. line_data.hash .. "^")
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

    local Command = require("trunks._core.command")
    local command_builder = Command.base_command("log --follow " .. filename, filename)

    -- Use the same lines that the log UI uses
    require("trunks._ui.home_options.log").set_lines(
        bufnr,
        { command_builder = command_builder, ui_types = { "time_machine" } }
    )

    -- Track renames: get filename for each commit asynchronously
    local filename_by_commit = {}
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
                    if vim.startswith(line, "R") and current_commit then
                        current_filename = line:match("%s(%S+)")
                        filename_by_commit[current_commit] = current_filename
                    elseif current_commit then
                        filename_by_commit[current_commit] = current_filename
                    end
                end
            end
        end,
    })

    set_keymaps(bufnr, filename, filename_by_commit)

    require("trunks._ui.auto_display").create_auto_display(bufnr, "time_machine", {
        generate_cmd = function()
            local ok, line_data = pcall(M._get_line, bufnr)
            if not ok or not line_data then
                return
            end

            -- Use historical name if found, otherwise fall back to current filename
            local filename_to_use = filename_by_commit[line_data.hash] or filename

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

return M
