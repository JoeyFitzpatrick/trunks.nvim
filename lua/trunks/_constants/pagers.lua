---@class trunks.Pager
---@field prefix? string
---@field postfix? string

local M = {}

---@type table<string, trunks.Pager>
M.PAGERS = {
    delta = { postfix = "delta --hunk-header-style=raw --paging=never" },
    ["diff-so-fancy"] = { postfix = "diff-so-fancy" },
    difft = { prefix = "-c diff.external=difft" },
}

return M
