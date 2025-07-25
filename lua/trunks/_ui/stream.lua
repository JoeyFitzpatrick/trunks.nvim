---@class trunks.StreamLinesOpts
---@field silent? boolean
---@field transform_line? fun(line: string): string
---@field highlight_line? fun(bufnr: integer, line: string, line_num: integer)
---@field on_exit? fun(bufnr: integer)
---@field filetype? string
---@field filter_empty_lines? boolean
---@field start_line? integer

local M = {}

---@param bufnr integer
---@param cmd string
---@param opts trunks.StreamLinesOpts
function M.stream_lines(bufnr, cmd, opts)
    local POSSIBLE_ERROR_OUTPUT = nil
    if not vim.api.nvim_buf_is_valid(bufnr) then
        return
    end
    if opts.filetype then
        vim.api.nvim_set_option_value("filetype", opts.filetype, { buf = bufnr })
    end

    local line_num = opts.start_line or 0
    local line_buffer = {}

    -- Add a line buffer to process chunks of lines
    local MAX_BUFFER_SIZE = 1000

    local function flush_buffer()
        if #line_buffer == 0 or not vim.api.nvim_buf_is_valid(bufnr) then
            return
        end

        vim.bo[bufnr].modifiable = true
        local lines_to_add = {}

        for _, line in ipairs(line_buffer) do
            if opts.transform_line then
                line = opts.transform_line(line)
            end
            if not (opts.filter_empty_lines and line == "") then
                table.insert(lines_to_add, line)
            end
        end

        if #lines_to_add > 0 then
            vim.api.nvim_buf_set_lines(bufnr, line_num, line_num + #lines_to_add, false, lines_to_add)

            if opts.highlight_line then
                for i, line in ipairs(lines_to_add) do
                    pcall(opts.highlight_line, bufnr, line, line_num + i - 1)
                end
            end

            line_num = line_num + #lines_to_add
        end

        vim.bo[bufnr].modifiable = false

        line_buffer = {}
    end

    local function on_stdout(_, data, _)
        if data then
            for _, line in ipairs(data) do
                POSSIBLE_ERROR_OUTPUT = line
                table.insert(line_buffer, line)

                if #line_buffer >= MAX_BUFFER_SIZE then
                    flush_buffer()
                    -- Add a small delay to allow the UI to update
                    vim.schedule(function() end)
                end
            end
        end
    end

    local function on_exit(_, code, _)
        flush_buffer()

        if opts.filetype then
            vim.bo[bufnr].filetype = opts.filetype
        end
        vim.bo[bufnr].modifiable = false

        if code ~= 0 and not opts.silent then
            local error_message = "command '" .. cmd .. "' failed with exit code " .. code
            if POSSIBLE_ERROR_OUTPUT and POSSIBLE_ERROR_OUTPUT ~= "" then
                error_message = "command '" .. cmd .. "' failed with message: " .. POSSIBLE_ERROR_OUTPUT
            end

            vim.notify(error_message, vim.log.levels.ERROR)
        end
        if opts.on_exit then
            opts.on_exit(bufnr)
        end
    end

    -- Remove existing lines before adding new lines.
    require("trunks._ui.utils.buffer_text").set(bufnr, {}, opts.start_line or 0, -1)

    -- Start the asynchronous job
    vim.fn.jobstart(cmd, {
        on_stdout = function(...)
            pcall(on_stdout, ...)
        end,
        on_stderr = function(...)
            pcall(on_stdout, ...)
        end,
        on_exit = function(...)
            pcall(on_exit, ...)
        end,
    })
end

return M
