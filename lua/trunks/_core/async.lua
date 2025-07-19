local M = {}

---@param func function
function M.run_async(func)
    local co = coroutine.create(func)
    coroutine.resume(co)
end

return M
