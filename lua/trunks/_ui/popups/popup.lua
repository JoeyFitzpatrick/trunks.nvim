---@class trunks.PopupMapping
---@field keys string
---@field description string
---@field action string | function

---@class trunks.PopupColumn
---@field title string
---@field rows trunks.PopupMapping[]

---@class trunks.RenderPopupOpts
---@field ui_type? string
---@field title string
---@field buffer_name string
---@field mappings? trunks.PopupMapping[]

local M = {}

---@param bufnr integer
---@param mapping_config string | trunks.PopupMapping[]
---@param title string
---@return string[]
local function get_popup_lines(bufnr, mapping_config, title)
    if type(mapping_config) == "string" then
        local ui_type = mapping_config
        local mappings = require("trunks._core.configuration").DATA[ui_type].keymaps
        local descriptions = require("trunks._constants.keymap_descriptions").long_descriptions[ui_type]
        local lines = { " " .. title }
        for command, keys in pairs(mappings) do
            table.insert(lines, string.format(" %s %s\t", keys, descriptions[command]))
        end
        return lines
    elseif type(mapping_config) == "table" then
        local lines = { " " .. title }
        for _, mapping in ipairs(mapping_config) do
            table.insert(lines, string.format(" %s %s\t", mapping.keys, mapping.description))
            require("trunks._ui.keymaps.set").safe_set_keymap("n", mapping.keys, function()
                -- Close the popup before performing the action. This prevents issues where
                -- a nested popup doesn't render because the action opens a popup, which is
                -- then immediately closed.
                require("trunks._core.register").deregister_buffer(bufnr)
                if type(mapping.action) == "string" then
                    vim.cmd(mapping.action)
                else
                    mapping.action()
                end
            end, { buffer = bufnr, silent = true, nowait = true, desc = mapping.description })
        end
        return lines
    end
    -- We should never get here
    return {}
end

local function highlight(bufnr)
    require("trunks._ui.highlight").highlight_line(bufnr, "Function", 0, 1, -1)
    -- We highlight the first line differently, so skip the first line in this loop
    for i, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 1, -1, false)) do
        local keys_start, keys_end = line:find("%s%w+%s")
        while keys_start and keys_end do
            require("trunks._ui.highlight").highlight_line(bufnr, "Keyword", i, keys_start, keys_end)
            keys_start, keys_end = line:find("%s%s+%w+", keys_end)
        end
    end
end

local function set_popup_settings()
    vim.wo.number = false
    vim.wo.relativenumber = false
end

---@param opts trunks.RenderPopupOpts
function M.render_popup(opts)
    local elements = require("trunks._ui.elements")
    local bufnr = elements.new_buffer({
        buffer_name = opts.buffer_name,
        hidden = true,
        lines = function(new_bufnr)
            if opts.ui_type then
                return get_popup_lines(new_bufnr, opts.ui_type, opts.title)
            elseif opts.mappings then
                return get_popup_lines(new_bufnr, opts.mappings, opts.title)
            end
            return {}
        end,
    })

    local width = math.floor(vim.o.columns * 0.9)
    local height = math.floor(vim.o.lines * 0.4)
    local col = math.floor((vim.o.columns - width) / 2)
    local row = vim.o.lines - height - 2
    elements.float(bufnr, {
        height = height,
        width = width,
        col = col,
        row = row,
        border = "solid",
    })

    set_popup_settings()
    highlight(bufnr)
    return bufnr
end

M._PADDING = 6

---@param bufnr integer
---@param columns trunks.PopupColumn[]
---@return string[]
function M.set_popup_lines(bufnr, columns)
    local rows = {}
    local column_widths = {}
    local padding = 1

    -- First pass: calculate maximum width for each column
    for col_idx, col in ipairs(columns) do
        local max_width = #col.title
        for _, row in ipairs(col.rows) do
            local line_length = #row.keys + 1 + #row.description -- +1 for space between keys and description
            max_width = math.max(max_width, line_length)
        end
        column_widths[col_idx] = max_width
    end

    -- Build title row
    local title_row = ""
    for col_idx, col in ipairs(columns) do
        title_row = title_row .. string.rep(" ", padding) .. col.title
        if col_idx < #columns then
            local spacing = column_widths[col_idx] - #col.title + M._PADDING
            title_row = title_row .. string.rep(" ", spacing)
        end
    end

    -- Build content rows with proper spacing
    for row_idx = 1, math.max(unpack(vim.tbl_map(function(col)
        return #col.rows
    end, columns))) do
        local row = ""
        for col_idx, col in ipairs(columns) do
            row = row .. string.rep(" ", padding)
            if col.rows[row_idx] then
                local content = string.format("%s %s", col.rows[row_idx].keys, col.rows[row_idx].description)
                row = row .. content
                if col_idx < #columns then
                    local spacing = column_widths[col_idx] - #content + M._PADDING
                    row = row .. string.rep(" ", spacing)
                end
            end

            -- Set up keymaps for this row
            if col.rows[row_idx] then
                require("trunks._ui.keymaps.set").safe_set_keymap("n", col.rows[row_idx].keys, function()
                    require("trunks._core.register").deregister_buffer(bufnr)
                    if type(col.rows[row_idx].action) == "string" then
                        vim.cmd(col.rows[row_idx].action)
                    else
                        col.rows[row_idx].action()
                    end
                end, {
                    buffer = bufnr,
                    silent = true,
                    nowait = true,
                    desc = col.rows[row_idx].description,
                })
            end
        end
        table.insert(rows, row)
    end

    table.insert(rows, 1, title_row)
    require("trunks._ui.utils.buffer_text").set(bufnr, rows)
    return rows
end

return M
