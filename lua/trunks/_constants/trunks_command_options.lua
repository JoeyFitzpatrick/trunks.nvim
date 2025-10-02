local M = {}

M.options = {
    ["commit-drop"] = {},
    ["commit-instant-fixup"] = {},
    ["diff-qf"] = {},
    hdiff = { completion_type = "branch" },
    vdiff = { completion_type = "branch" },
    ["time-machine"] = { completion_type = "filepath" },
    ["time-machine-next"] = {},
    ["time-machine-previous"] = {},
}

M.commands = vim.tbl_keys(M.options)
table.sort(M.commands)

return M
