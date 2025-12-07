---@class trunks.TabHighlightIndices
---@field start integer
---@field ending integer

---@alias trunks.TabOption "Status" | "Branch" | "Log" | "Stash"

---@class trunks.UiRenderOpts
---@field command_builder? trunks.Command -- The command used for this UI
---@field keymap_opts? trunks.GetKeymapsOpts
---@field win? integer
---@field ui_types? string[]

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
    Status = function()
        return require("trunks._ui.home_options.status").render()
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

---@param bufnr integer
---@param tab trunks.TabOption
local function set_keymaps_and_user_commands(bufnr, tab)
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
    require("trunks._core.autocmds").execute_user_autocmds({ ui_type = "buffer", ui_name = string.lower(tab) })
end

---@param tab trunks.TabOption
function M.create_and_render_buffer(tab)
    local ui_render = tab_render_map[tab]
    local ui_types = { "home", string.lower(tab) }

    local bufnr, win = ui_render()

    require("trunks._core.register").register_buffer(bufnr, {
        render_fn = function()
            local cursor = vim.api.nvim_win_get_cursor(win)
            local new_bufnr, new_win = ui_render()
            vim.api.nvim_win_set_cursor(new_win, cursor)
            set_keymaps_and_user_commands(new_bufnr, tab)
        end,
        state = { display_auto_display = true },
    })

    set_keymaps_and_user_commands(bufnr, tab)
end

function M.open()
    vim.cmd("tabnew")
    tabs:set_current(1) -- TODO: move this into on-close autocmd once we have that
    M.create_and_render_buffer(tabs.current_option)
end

return M
