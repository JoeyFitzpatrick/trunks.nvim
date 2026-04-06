local M = {}

function M.reset_to_remote()
    vim.cmd("G reset --hard @{u}")
end

return M
