local M = {}

--- Async, must run in a coroutine or using our async helpers (`run_async`)
---@param message string
---@param opts? { values: string[] }
---@return boolean
function M.confirm_choice(message, opts)
    opts = opts or {}
    opts.values = opts.values or { "Yes", "No" }
    local co = coroutine.running()
    if not co then
        error("confirm_choice must be called from within a coroutine")
    end

    vim.ui.select(opts.values, { prompt = message }, function(choice)
        coroutine.resume(co, choice == opts.values[1])
    end)

    return coroutine.yield()
end

return M
