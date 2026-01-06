---@class trunks.TabHighlightIndices
---@field start integer
---@field ending integer

---@alias trunks.TabOption "Status" | "Branch" | "Log" | "Stash"

---@class trunks.UiRenderOpts
---@field command_builder? trunks.Command -- The command used for this UI
---@field set_keymaps? fun(bufnr: integer)
---@field win? integer
---@field ui_types? string[]
---@field display_strategy? trunks.DisplayStrategy

local M = {}

local TAB_OPTIONS = { "Status", "Branch", "Log", "Stash" }

local tabs = {
    _options = TAB_OPTIONS,
    current = 1,
    current_option = TAB_OPTIONS[1],
    set_current = function(self, index)
        if index < 1 then
            self.current = 1
        elseif index > #self._options then
            self.current = #self.options
        else
            self.current = index
        end
        self.current_option = self._options[self.current]
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
    end,
}

---@type table<trunks.TabOption, fun(bufnr: integer, opts: trunks.UiRenderOpts)>
local tab_render_map = {
    Status = function(bufnr, opts)
        return require("trunks._ui.home_options.status").render(bufnr, opts)
    end,
    Branch = function(bufnr, opts)
        return require("trunks._ui.home_options.branch").render(bufnr, opts)
    end,
    Log = function(bufnr, opts)
        require("trunks._ui.home_options.log").render(bufnr, opts)
    end,
    Stash = function(bufnr, opts)
        require("trunks._ui.home_options.stash").render(bufnr, opts)
    end,
}

---@param bufnr integer
---@param tab trunks.TabOption
local function set_keymaps(bufnr)
    local keymaps = require("trunks._core.configuration").DATA.home.keymaps
    if not keymaps then
        return
    end

    local set = require("trunks._ui.keymaps.set").safe_set_keymap
    set("n", keymaps.next, function()
        local old_bufnr = bufnr
        tabs:cycle_tab("forward")
        M.create_and_render_buffer(tabs.current_option)
        require("trunks._core.register").deregister_buffer(old_bufnr, { delete_win_buffers = false })
    end, { buffer = bufnr })

    set("n", keymaps.previous, function()
        local old_bufnr = bufnr
        tabs:cycle_tab("back")
        M.create_and_render_buffer(tabs.current_option)
        require("trunks._core.register").deregister_buffer(old_bufnr, { delete_win_buffers = false })
    end, { buffer = bufnr })
end

---@param bufnr? integer
local function remove_leftover_new_tab_buffer(bufnr)
    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
        vim.api.nvim_buf_delete(bufnr, {})
        local current_win = vim.api.nvim_get_current_win()
        require("trunks._core.register").last_non_trunks_buffer_for_win[current_win] = nil
    end
end

---@param tab trunks.TabOption
---@param existing_bufnr? integer
function M.create_and_render_buffer(tab, existing_bufnr)
    local bufnr = require("trunks._ui.elements").new_buffer({})
    local ui_render = tab_render_map[tab]
    ui_render(bufnr, { set_keymaps = set_keymaps, display_strategy = "full" })

    remove_leftover_new_tab_buffer(existing_bufnr)
end

function M.open()
    vim.cmd("tabnew")
    local existing_bufnr = vim.api.nvim_get_current_buf()
    tabs:set_current(1)
    M.create_and_render_buffer(tabs.current_option, existing_bufnr)
end

return M
