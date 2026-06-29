local M = {}

-- Set by trunks on the terminal jobs it launches (see _ui/elements.lua). Its
-- presence tells a nested Nvim that it was spawned as the editor for a trunks
-- git command, so it should hand its file off to the parent -- reached through
-- the built-in $NVIM socket -- instead of opening a nested session.
M.nested_marker_env_var = "NVIM_TRUNKS_NESTED"

return M
