---@class trunks.TabHighlightIndices
---@field start integer
---@field ending integer

---@alias trunks.TabOption "Status" | "Branch" | "Log" | "Stash"

---@class trunks.UiRenderOpts
---@field start_line? integer
---@field command_builder? trunks.Command -- The command used for this UI
---@field keymap_opts? trunks.GetKeymapsOpts
---@field win? integer
---@field ui_types? string[]

local M = {}

-- includes padding and keymap text
local TAB_HEIGHT = 6

--- Creates tabs for home UI
---@param options string[]
---@return string[], trunks.TabHighlightIndices[]
function M._create_box_table(options)
    local boxes = {}
    local indices = {}
    local separator = "  "
    local top_line, middle_line, bottom_line = separator, separator, separator
    local separator_len = separator:len()

    for _, option in ipairs(options) do
        local box_width = math.max(#option + 2, 7)
        local padding = math.floor((box_width - #option) / 2)

        ---@type string
        local top_str_to_add = "┌" .. string.rep("─", box_width) .. "┐" .. separator
        top_line = top_line .. top_str_to_add

        local middle_str_to_add = "│"
            .. string.rep(" ", padding)
            .. option
            .. string.rep(" ", box_width - #option - padding)
            .. "│"
            .. separator
        middle_line = middle_line .. middle_str_to_add

        local bottom_str_to_add = "└" .. string.rep("─", box_width) .. "┘" .. separator
        bottom_line = bottom_line .. bottom_str_to_add

        table.insert(indices, {
            {
                start = top_line:len() - top_str_to_add:len() + string.len("┌"),
                ending = top_line:len() - separator_len,
            },
            {
                start = middle_line:len() - middle_str_to_add:len() + string.len("│"),
                ending = middle_line:len() - separator_len,
            },
            {
                start = bottom_line:len() - bottom_str_to_add:len() + string.len("└"),
                ending = bottom_line:len() - separator_len,
            },
        })
    end

    table.insert(boxes, top_line:sub(1, -#separator - 1))
    table.insert(boxes, middle_line:sub(1, -#separator - 1))
    table.insert(boxes, bottom_line:sub(1, -#separator - 1))
    -- Add padding
    table.insert(boxes, "")

    return boxes, indices
end

local TAB_OPTIONS = { "Status", "Branch", "Log", "Stash" }
local tabs_text, tab_indices = M._create_box_table(TAB_OPTIONS)

local tabs = {
    _options = TAB_OPTIONS,
    _tab_indices = tab_indices,
    current = 1,
    current_option = TAB_OPTIONS[1],
    current_tab_indices = tab_indices[1],
    set_current = function(self, index)
        if index < 1 then
            self.current = 1
        elseif index > #self._options then
            self.current = #self.options
        else
            self.current = index
        end
        self.current_option = self._options[self.current]
        self.current_tab_indices = self._tab_indices[self.current]
    end,
    ---@param direction "forward" | "back"
    cycle_tab = function(self, direction)
        if direction == "forward" then
            if self.current >= #self._options then
                self.current = 1
            else
                self.current = self.current + 1
            end
        else
            if self.current <= 1 then
                self.current = #self._options
            else
                self.current = self.current - 1
            end
        end
        self.current_option = self._options[self.current]
        self.current_tab_indices = self._tab_indices[self.current]
    end,
}

local highlight_namespace = vim.api.nvim_create_namespace("TrunksHomeTabs")

---@param bufnr integer
---@param indices trunks.TabHighlightIndices[]
local function highlight_tabs(bufnr, indices)
    vim.api.nvim_buf_clear_namespace(bufnr, highlight_namespace, 2, 5)
    for i = 1, 3 do
        vim.hl.range(bufnr, highlight_namespace, "Conceal", { i + 1, 1 }, { i + 1, indices[i].start - 4 })
        vim.hl.range(bufnr, highlight_namespace, "Conceal", { i + 1, indices[i].ending }, { i + 1, -1 })
    end
end

---@type table<trunks.TabOption, fun(bufnr: integer, opts: trunks.UiRenderOpts)>
local tab_render_map = {
    Status = function(bufnr, opts)
        require("trunks._ui.home_options.status").render(bufnr, opts)
    end,
    Branch = function(bufnr, opts)
        require("trunks._ui.home_options.branch").render(bufnr, opts)
    end,
    Log = function(bufnr, opts)
        require("trunks._ui.home_options.log").render(bufnr, opts)
    end,
    Stash = function(bufnr, opts)
        require("trunks._ui.home_options.stash").render(bufnr, opts)
    end,
}

---@param tab trunks.TabOption
---@param indices trunks.TabHighlightIndices[]
local function create_and_render_buffer(tab, indices)
    local bufnr, win = require("trunks._ui.elements").new_buffer({})
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, tabs_text)
    local ui_render = tab_render_map[tab]
    require("trunks._core.register").register_buffer(bufnr, {
        render_fn = function()
            ui_render(bufnr, { start_line = TAB_HEIGHT, ui_types = { "home", string.lower(tab) } })
        end,
    })

    vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
    ui_render(bufnr, { start_line = TAB_HEIGHT, win = win, ui_types = { "home", string.lower(tab) } })
    vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
    local line_to_set_cursor_to = TAB_HEIGHT + 3
    if tab == "Status" then
        line_to_set_cursor_to = line_to_set_cursor_to + 2
    end
    vim.api.nvim_win_set_cursor(win, { math.min(vim.api.nvim_buf_line_count(bufnr), line_to_set_cursor_to), 0 })
    highlight_tabs(bufnr, indices)

    local keymaps = require("trunks._core.configuration").DATA.home.keymaps
    if not keymaps then
        return
    end
    local set = require("trunks._ui.keymaps.set").safe_set_keymap

    set("n", "q", function()
        require("trunks._core.register").deregister_buffer(bufnr)
    end, { buffer = bufnr })

    set("n", keymaps.next, function()
        local old_bufnr = bufnr
        require("trunks._core.register").deregister_buffer(old_bufnr)
        tabs:cycle_tab("forward")
        create_and_render_buffer(tabs.current_option, tabs.current_tab_indices)
    end, { buffer = bufnr })

    set("n", keymaps.previous, function()
        local old_bufnr = bufnr
        require("trunks._core.register").deregister_buffer(old_bufnr)
        tabs:cycle_tab("back")
        create_and_render_buffer(tabs.current_option, tabs.current_tab_indices)
    end, { buffer = bufnr })
end

function M.open()
    tabs:set_current(1) -- TODO: move this into on-close autocmd once we have that
    create_and_render_buffer(tabs.current_option, tabs.current_tab_indices)
end

return M
