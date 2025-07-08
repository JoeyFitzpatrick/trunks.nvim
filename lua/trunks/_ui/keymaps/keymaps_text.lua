local M = {}

---@param bufnr integer
---@param ui_types string[]
function M.show(bufnr, ui_types)
    local keymaps_string = require("trunks._constants.keymap_descriptions").get_short_descriptions_as_string(ui_types)
    require("trunks._ui.utils.buffer_text").set(bufnr, { keymaps_string }, 0, 0)

    -- Highlight
    local mapping_hlgroup = "Keyword"
    local first_mapping_start, first_mapping_end = keymaps_string:find("%S+", 0, false)
    require("trunks._ui.highlight").highlight_line(bufnr, mapping_hlgroup, 0, first_mapping_start, first_mapping_end)
    local pipe_index = keymaps_string:find("|", first_mapping_end, true)
    while pipe_index do
        require("trunks._ui.highlight").highlight_line(bufnr, "Comment", 0, pipe_index, pipe_index + 1)
        local mapping_start, mapping_end = keymaps_string:find("%S+", pipe_index + 1, false)
        require("trunks._ui.highlight").highlight_line(bufnr, mapping_hlgroup, 0, mapping_start, mapping_end)
        pipe_index = keymaps_string:find("|", pipe_index + 1, true)
    end
end

return M
