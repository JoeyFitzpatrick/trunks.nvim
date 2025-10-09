-- Example demonstrating diff syntax highlighting
-- This module is for testing/demonstration purposes only
-- Source this file to see if multi-filetype highlighting is working (e.g. :source)

local M = {}

function M.demo()
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_win_set_buf(0, bufnr)

    -- Sample diff output with lua and c files
    local diff_content = {
        "diff --git c/lua/trunks/_ui/home.lua w/lua/trunks/_ui/home.lua",
        "index 85f002f..9ca2ccd 100644",
        "--- c/lua/trunks/_ui/home.lua",
        "+++ w/lua/trunks/_ui/home.lua",
        "@@ -144,9 +144,17 @@ local function create_and_render_buffer(tab, indices)",
        '    local bufnr, win = require("trunks._ui.elements").new_buffer({})',
        '    require("trunks._ui.utils.buffer_text").set(bufnr, tabs_text)',
        "    local ui_render = tab_render_map[tab]",
        '    local set = require("trunks._ui.keymaps.set").safe_set_keymap',
        "",
        '    require("trunks._core.register").register_buffer(bufnr, {',
        "        render_fn = function()",
        '            ui_render(bufnr, { start_line = TAB_HEIGHT, ui_types = { "home", string.lower(tab) } })',
        "+",
        '+            -- In home UI, we want "q" to close tabs, so we have to re-set this after rerender',
        '+            set("n", "q", function()',
        '+                require("trunks._core.register").deregister_buffer(bufnr)',
        '+                vim.cmd("tabclose")',
        "+            end, { buffer = bufnr })",
        "        end,",
        "    })",
        "",
        "diff --git a/src/example.c b/src/example.c",
        "index 1234567..abcdefg 100644",
        "--- a/src/example.c",
        "+++ b/src/example.c",
        "@@ -10,7 +10,8 @@ int main() {",
        "    int x = 42;",
        '    printf("Hello World\\n");',
        "-    return 0;",
        "+    // Added cleanup",
        "+    return EXIT_SUCCESS;",
        "}",
    }

    vim.bo.modifiable = true
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, diff_content)
    vim.bo.modifiable = false
    vim.bo.filetype = "git"
    vim.keymap.set("n", "q", function()
        vim.api.nvim_buf_delete(0, { force = true })
    end, { buffer = 0 })

    require("trunks._ui.diff_syntax").apply_syntax(bufnr)
end

M.demo()

return M
