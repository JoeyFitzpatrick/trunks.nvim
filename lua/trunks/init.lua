if vim.g.loaded_trunks then
    return
end

require("trunks._core.configuration").initialize_data()
require("trunks._core.highlight").initialize_highlights()
require("trunks._core.signcolumn").initialize_signcolumns()
require("trunks._core.nested-buffers").setup_nested_buffers()
require("trunks._core.autocmds").setup_autocmds()
require("trunks._core.virtual_buffers").setup()

vim.g.loaded_trunks = true
