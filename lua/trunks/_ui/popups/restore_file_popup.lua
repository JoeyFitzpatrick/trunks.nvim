local M = {}

local run_write_cmd = require("trunks._core.run_cmd").run_write_cmd

local function remove_untracked_file(filename)
    run_write_cmd("git clean -f " .. filename)

    -- File/dir can still exist in some edge cases, for example, if it's an empty dir with a .git folder.
    -- In this case, currently we no-op, but documenting here for future reference.
end

---@param bufnr integer
---@param line_num integer
---@param get_line fun(bufnr: integer, line_num: integer): trunks.StatusLineData | nil
function M.render(bufnr, line_num, get_line)
    require("trunks._ui.popups.popup").render_popup({
        buffer_name = "TrunksStatusDeletePopup",
        title = "Git Restore Type",
        mappings = {
            {
                keys = "f",
                description = "Just this file",
                action = function()
                    local ok, line_data = pcall(get_line, bufnr, line_num)
                    if not ok or not line_data then
                        return
                    end
                    local filename = line_data.filename
                    local status = line_data.status
                    local is_untracked = status == "?"
                    if is_untracked then
                        remove_untracked_file(filename)
                    else
                        run_write_cmd({ "git reset -- " .. filename, "git restore -- " .. filename })
                    end
                end,
            },
            {
                keys = "u",
                description = "Unstaged changes for this file",
                action = function()
                    local ok, line_data = pcall(get_line, bufnr, line_num)
                    if not ok or not line_data then
                        return
                    end
                    local filename = line_data.safe_filename
                    local status = line_data.status
                    local status_checks = require("trunks._core.git")
                    if status_checks.is_untracked(status) then
                        remove_untracked_file(filename)
                    else
                        -- Worth noting that lazygit does git -c core.hooksPath=/dev/null checkout -- filename
                        run_write_cmd("git restore -- " .. filename)
                    end
                end,
            },
            {
                keys = "n",
                description = "Nuke working tree",
                action = function()
                    run_write_cmd("git reset --hard HEAD")
                    run_write_cmd("git clean -fd")
                end,
            },
            {
                keys = "h",
                description = "Hard reset",
                action = function()
                    run_write_cmd("git reset --hard HEAD")
                end,
            },
            {
                keys = "s",
                description = "Soft reset",
                action = function()
                    run_write_cmd("git reset --soft HEAD")
                end,
            },
            {
                keys = "m",
                description = "Mixed reset",
                action = function()
                    run_write_cmd("git reset --mixed HEAD")
                end,
            },
        },
    })
end

return M
