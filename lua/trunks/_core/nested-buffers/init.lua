-- Prevents nested Nvim sessions (e.g. the editor `git commit` spawns) by
-- handing the file off to the running instance. Relies on the built-in
-- $NVIM environment variable that Nvim automatically sets for every process it
-- spawns (and their descendants, e.g. terminal -> git -> nvim).

local constants = require("trunks._core.nested-buffers.constants")

local M = {}

--- Child side: run inside a nested Nvim. If we were spawned as the editor for a
--- trunks git command (marker set) and can reach the parent via $NVIM, redirect
--- our file to the parent instead of opening here.
M.prevent_nested_buffers = function()
    local spawned_by_trunks = os.getenv(constants.nested_marker_env_var) ~= nil
    local has_parent = os.getenv("NVIM") ~= nil
    if spawned_by_trunks and has_parent then
        require("trunks._core.nested-buffers.client")
    end
end

--- Parent side: define the RPC handlers the nested Nvim will call. The parent is
--- reached through its built-in server ($NVIM).
M.setup_nested_buffers = function()
    if require("trunks._core.configuration").DATA.prevent_nvim_inception then
        require("trunks._core.nested-buffers.server")
    end
end

--- Environment for terminal jobs that may spawn an editor. Forces git to use
--- this Nvim binary as its editor and marks the job so the nested Nvim knows it should redirect.
---@return table<string, string>?
M.editor_job_env = function()
    if not require("trunks._core.configuration").DATA.prevent_nvim_inception then
        return nil
    end
    local progpath = vim.v.progpath
    return {
        [constants.nested_marker_env_var] = "1",
        -- Nvim sets $NVIM for children automatically, but set it explicitly so
        -- it survives even when we pass a custom `env` to the job.
        NVIM = vim.v.servername,
        EDITOR = progpath,
        VISUAL = progpath,
        GIT_EDITOR = progpath,
        GIT_SEQUENCE_EDITOR = progpath,
    }
end

return M
