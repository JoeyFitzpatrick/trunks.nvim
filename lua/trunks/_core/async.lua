local M = {}

---@param func function
function M.run_async(func)
    local co = coroutine.create(func)
    local success, result = coroutine.resume(co)
    return success, result
end

return M
