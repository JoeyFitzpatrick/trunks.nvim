---@class trunks.Pager
---@field type "prefix" | "postfix"
---@field command string

local M = {}

---@type table<string, trunks.Pager>
M.PAGERS = {
    delta = { type = "postfix", command = "delta --paging=never" },
    ["diff-so-fancy"] = { type = "postfix", command = "diff-so-fancy" },
    difft = { type = "prefix", command = "-c diff.external=difft" },
}

return M
