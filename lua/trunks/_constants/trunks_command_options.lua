local M = {}

M.options = {
    ["commit-drop"] = { options = {} },
    ["commit-instant-fixup"] = { options = {} },
    hdiff = { completion_type = "branch", options = {} },
    vdiff = { completion_type = "branch", options = {} },
    ["time-machine"] = { completion_type = "filepath", options = {} },
    ["time-machine-next"] = { options = {} },
    ["time-machine-previous"] = { options = {} },
}

M.commands = vim.tbl_keys(M.options)
table.sort(M.commands)

return M
