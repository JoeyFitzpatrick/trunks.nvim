local M = {}

---@param channel_id integer
---@param bufnr integer
function M.display_extra_info(channel_id, bufnr)
    local elements = require("trunks._ui.elements")
    local ui_utils = require("trunks._ui.utils.ui_utils")
    local Command = require("trunks._core.command")
    local results = { head = nil, diff = nil }

    local function render_if_ready()
        if results.head and results.diff then
            elements.term_controls.go_home(channel_id)
            elements.term_controls.add_line(channel_id, results.head)
            elements.term_controls.add_line(channel_id, results.diff)
            ui_utils.set_start_line(bufnr, 2)
        end
    end

    -- Async fetch current head
    local head_cmd = Command.base_command("symbolic-ref --short HEAD"):build()
    vim.system(vim.split(head_cmd, " "), {}, function(obj)
        vim.schedule(function()
            local purple = "\27[35m"
            local blue = "\27[34m"
            local reset = "\27[0m"

            if obj.code == 0 and obj.stdout and obj.stdout ~= "" then
                local branch_name = vim.trim(obj.stdout)
                results.head = purple .. "Head:" .. blue .. " " .. branch_name .. reset
                render_if_ready()
            else
                -- Detached head fallback
                local hash_cmd = Command.base_command("rev-parse --short HEAD"):build()
                vim.system(vim.split(hash_cmd, " "), {}, function(hash_obj)
                    vim.schedule(function()
                        if hash_obj.code == 0 and hash_obj.stdout and hash_obj.stdout ~= "" then
                            local hash = vim.trim(hash_obj.stdout)
                            results.head = purple .. "Head:" .. blue .. " " .. hash .. " (detached head)" .. reset
                        else
                            results.head = purple .. "Head:" .. blue .. " Unable to find current HEAD" .. reset
                        end
                        render_if_ready()
                    end)
                end)
            end
        end)
    end)

    -- Async fetch staged changes
    local diff_cmd = Command.base_command("diff --staged --shortstat"):build({ no_pager = true })
    vim.system(vim.split(diff_cmd, " "), {}, function(obj)
        vim.schedule(function()
            if obj.code == 0 and obj.stdout and obj.stdout ~= "" then
                results.diff = vim.trim(obj.stdout):gsub("\n", "")
            else
                results.diff = "No staged changes"
            end
            render_if_ready()
        end)
    end)
end

return M
