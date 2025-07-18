---@class trunks.RenderPopupMapping
---@field keys string
---@field description string
---@field action string | function

---@class trunks.RenderPopupOpts
---@field ui_type? string
---@field title string
---@field buffer_name string
---@field mappings? trunks.RenderPopupMapping[]

local M = {}

---@param bufnr integer
---@param mapping_config string | trunks.RenderPopupMapping[]
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
        local keys_start, keys_end = line:find("%s?%w+%s")
        require("trunks._ui.highlight").highlight_line(bufnr, "Keyword", i, keys_start, keys_end)
    end
end

local function set_popup_settings()
    vim.opt.number = false
    vim.opt.relativenumber = false
end

local function set_keymaps(bufnr)
    vim.keymap.set("n", "q", function()
        require("trunks._core.register").deregister_buffer(bufnr)
    end, { buffer = bufnr, noremap = true, nowait = true })
end

---@param opts trunks.RenderPopupOpts
function M.render_popup(opts)
    local bufnr = require("trunks._ui.elements").new_buffer({
        buffer_name = opts.buffer_name,
        win_config = { split = "below" },
        lines = function(new_bufnr)
            if opts.ui_type then
                return get_popup_lines(new_bufnr, opts.ui_type, opts.title)
            elseif opts.mappings then
                return get_popup_lines(new_bufnr, opts.mappings, opts.title)
            end
            return {}
        end,
    })
    set_popup_settings()
    highlight(bufnr)
    set_keymaps(bufnr)
    return bufnr
end

return M
