local M = {}

---@param bufnr integer
---@param line_num? integer
---@return { worktree: string, hash: string } | nil
local function get_line(bufnr, line_num)
    line_num = line_num or vim.api.nvim_win_get_cursor(0)[1]
    local line = vim.api.nvim_buf_get_lines(bufnr, line_num - 1, line_num, false)[1]
    if line == "" then
        return nil
    end
    return { worktree = line:match("󰌹%s+([^%s%(]+)"), hash = line:match("%x+$") }
end

local function set_keymaps(bufnr)
    local keymap_opts = { noremap = true, silent = true, buffer = bufnr, nowait = true }
    local keymaps = require("trunks._ui.keymaps.base").get_keymaps(bufnr, "worktree", {})
    local set = require("trunks._ui.keymaps.set").safe_set_keymap

    set("n", keymaps.new, function()
        local ok, line_data = pcall(get_line, bufnr)
        if not ok or not line_data then
            return
        end

        local project_name = vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
        local default_worktree_location = "../" .. project_name .. "+"

        vim.ui.select(
            require("trunks._completion.completion").get_branches(),
            { prompt = "Branch for new worktree" },
            function(worktree_branch)
                if not worktree_branch then
                    return
                end

                vim.ui.input({
                    prompt = "Name for new worktree off of " .. line_data.worktree .. ": ",
                    default = default_worktree_location,
                }, function(input)
                    if not input then
                        return
                    end
                    vim.cmd(string.format("G worktree add %s %s", input, worktree_branch))
                end)
            end
        )
    end, keymap_opts)

    set("n", keymaps.delete, function()
        local ok, line_data = pcall(get_line, bufnr)
        if not ok or not line_data then
            return
        end
        vim.ui.select(
            { "Yes", "No" },
            { prompt = "Are you sure you want to delete worktree " .. line_data.worktree .. "?" },
            function(selection)
                if not selection or selection ~= "Yes" then
                    return
                end
                vim.cmd(string.format("G worktree remove %s", line_data.worktree))
            end
        )
    end, keymap_opts)

    set("n", keymaps.switch, function()
        local ok, line_data = pcall(get_line, bufnr)
        if not ok or not line_data then
            return
        end
        vim.cmd(string.format("cd ../%s", line_data.worktree))
    end, keymap_opts)
end

---@param command_builder trunks.Command
---@return string[]
local function get_lines(command_builder)
    local worktrees = require("trunks._core.run_cmd").run_cmd(command_builder)
    local output = {}
    for _, line in ipairs(worktrees) do
        local worktree_name = line:match(".*/([^%s]*)")
        local worktree_hash = line:match("%s(%S+)")
        local worktree_branch = line:match("%[(.+)%]")
        table.insert(output, string.format(" 󰌹  %s (%s) -- %s", worktree_name, worktree_branch, worktree_hash))
    end
    return output
end

---@param command_builder trunks.Command
function M.render(command_builder)
    command_builder:add_args("list")
    local bufnr = require("trunks._ui.elements").new_buffer({
        buffer_name = "TrunksWorktree-" .. os.tmpname(),
        lines = function()
            return get_lines(command_builder)
        end,
    })
    set_keymaps(bufnr)
    require("trunks._core.register").register_buffer(bufnr, {
        render_fn = function()
            vim.bo[bufnr].modifiable = true
            vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, get_lines(command_builder))
            vim.bo[bufnr].modifiable = false
        end,
    })
end

return M
