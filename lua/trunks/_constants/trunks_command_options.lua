local M = {}

M.options = {
    ["browse"] = {},
    ["commit-details"] = {},
    ["commit-drop"] = {},
    ["commit-instant-fixup"] = {},
    edit = {},
    ["log-qf"] = {},
    ["reset-to-remote"] = {},
    hdiff = { completion_type = "branch" },
    vdiff = { completion_type = "branch" },
}

M.commands = vim.tbl_keys(M.options)
table.sort(M.commands)

return M
