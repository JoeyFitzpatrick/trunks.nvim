local M = {}

---@param keymaps_string string
local function display_keymaps_in_cmdline(keymaps_string)
    local chunks = {}
    local mapping_hlgroup = "Keyword"

    local first_mapping_start, first_mapping_end = keymaps_string:find("%S+", 0, false)
    if first_mapping_start then
        table.insert(chunks, { keymaps_string:sub(first_mapping_start, first_mapping_end), mapping_hlgroup })
    end

    -- Find all pipes and subsequent mappings
    local pipe_index = keymaps_string:find("|", first_mapping_end, true)
    local last_end = first_mapping_end

    while pipe_index do
        -- Add text between last mapping and pipe
        if pipe_index > last_end + 1 then
            table.insert(chunks, { keymaps_string:sub(last_end + 1, pipe_index - 1), "Normal" })
        end

        table.insert(chunks, { "|", "Comment" })

        -- Find next mapping after pipe
        local mapping_start, mapping_end = keymaps_string:find("%S+", pipe_index + 1, false)
        if mapping_start then
            if mapping_start > pipe_index + 1 then
                table.insert(chunks, { keymaps_string:sub(pipe_index + 1, mapping_start - 1), "Normal" })
            end
            table.insert(chunks, { keymaps_string:sub(mapping_start, mapping_end), mapping_hlgroup })
            last_end = mapping_end
        end

        pipe_index = keymaps_string:find("|", pipe_index + 1, true)
    end

    if last_end < #keymaps_string then
        table.insert(chunks, { keymaps_string:sub(last_end + 1), "Normal" })
    end

    vim.api.nvim_echo(chunks, false, {})
end

---@param bufnr integer
---@param ui_types string[] | nil
function M.show_in_cmdline(bufnr, ui_types)
    if not ui_types then
        return
    end

    local keymaps_string = require("trunks._constants.keymap_descriptions").get_short_descriptions_as_string(ui_types)

    display_keymaps_in_cmdline(keymaps_string)

    local augroup = vim.api.nvim_create_augroup("TrunksCmdline_" .. bufnr, { clear = true })
    vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
        group = augroup,
        buffer = bufnr,
        callback = function()
            display_keymaps_in_cmdline(keymaps_string)
        end,
    })

    vim.api.nvim_create_autocmd({ "BufLeave", "BufWinLeave" }, {
        group = augroup,
        buffer = bufnr,
        callback = function()
            vim.api.nvim_echo({ { "", "" } }, false, {})
        end,
    })
end

return M
