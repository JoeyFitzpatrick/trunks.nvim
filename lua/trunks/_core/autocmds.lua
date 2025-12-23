local M = {}

function M.setup_autocmds()
    vim.api.nvim_create_autocmd("WinClosed", {
        desc = "Remove this window from Trunks's internal navigation data",
        group = vim.api.nvim_create_augroup("TrunksRemoveWinFromNavigation", {}),
        callback = function(event)
            local win = tonumber(event.match)
            if not win then
                return
            end
            require("trunks._core.register").last_non_trunks_buffer_for_win[win] = nil
        end,
    })
end

---@param data { ui_type: "buffer" | "quickfix", ui_name: string }
function M.execute_user_autocmds(data)
    vim.api.nvim_exec_autocmds("User", {
        pattern = "TrunksUiOpened",
        data = data,
    })
end

function M.execute_rerender_autocmd()
    vim.api.nvim_exec_autocmds("User", {
        pattern = require("trunks._constants.constants").AUTOCMD.RERENDER,
    })
end

return M
