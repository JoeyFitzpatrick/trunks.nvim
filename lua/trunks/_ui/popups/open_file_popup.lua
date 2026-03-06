---@class trunks.OpenFilePopupOpts
---@field open_file_opts? trunks.OpenFileOpts
---@field before_split? function Called before horizontal/vertical split operations
---@field after_open? function(bufnr: integer) Called after the file is opened

local M = {}

---@param filename string
---@param commit string
---@param opts? trunks.OpenFilePopupOpts
function M.render(filename, commit, opts)
    opts = opts or {}
    local open_file_opts = opts.open_file_opts or {}
    local keymaps = require("trunks._ui.keymaps.base").get_keymaps(nil, "open_file_popup", { popup = true })
    local descriptions = require("trunks._constants.keymap_descriptions").long_descriptions.open_file_popup
    local open_file_module = require("trunks._core.open_file")

    ---@param open_type "window" | "right" | "below" | "tab"
    ---@param use_previous boolean Open at commit^ instead of commit
    ---@return function
    local function make_open_fn(open_type, use_previous)
        local commit_to_use = use_previous and (commit .. "^") or commit
        return function()
            if opts.before_split and (open_type == "right" or open_type == "below") then
                opts.before_split()
            end
            local new_bufnr
            if open_type == "tab" then
                new_bufnr = open_file_module.open_file_in_tab(filename, commit_to_use, open_file_opts)
            elseif open_type == "window" then
                new_bufnr = open_file_module.open_file_in_current_window(filename, commit_to_use, open_file_opts)
            elseif open_type == "right" then
                new_bufnr = open_file_module.open_file_in_split(filename, commit_to_use, "right", open_file_opts)
            elseif open_type == "below" then
                new_bufnr = open_file_module.open_file_in_split(filename, commit_to_use, "below", open_file_opts)
            end
            if opts.after_open and new_bufnr then
                opts.after_open(new_bufnr)
            end
        end
    end

    ---@type trunks.PopupColumn[]
    local columns = {
        {
            title = "Open at this commit",
            rows = {
                {
                    keys = keymaps.open_in_current_window,
                    description = descriptions.open_in_current_window,
                    action = make_open_fn("window", false),
                },
                {
                    keys = keymaps.open_in_vertical_split,
                    description = descriptions.open_in_vertical_split,
                    action = make_open_fn("right", false),
                },
                {
                    keys = keymaps.open_in_horizontal_split,
                    description = descriptions.open_in_horizontal_split,
                    action = make_open_fn("below", false),
                },
                {
                    keys = keymaps.open_in_new_tab,
                    description = descriptions.open_in_new_tab,
                    action = make_open_fn("tab", false),
                },
            },
        },
        {
            title = "Open at previous commit (^)",
            rows = {
                {
                    keys = keymaps.open_previous_in_current_window,
                    description = descriptions.open_previous_in_current_window,
                    action = make_open_fn("window", true),
                },
                {
                    keys = keymaps.open_previous_in_vertical_split,
                    description = descriptions.open_previous_in_vertical_split,
                    action = make_open_fn("right", true),
                },
                {
                    keys = keymaps.open_previous_in_horizontal_split,
                    description = descriptions.open_previous_in_horizontal_split,
                    action = make_open_fn("below", true),
                },
                {
                    keys = keymaps.open_previous_in_new_tab,
                    description = descriptions.open_previous_in_new_tab,
                    action = make_open_fn("tab", true),
                },
            },
        },
    }

    require("trunks._ui.popups.popup").render_popup({
        buffer_name = "TrunksOpenFilePopup",
        title = "Open " .. filename,
        columns = columns,
    })
end

return M
