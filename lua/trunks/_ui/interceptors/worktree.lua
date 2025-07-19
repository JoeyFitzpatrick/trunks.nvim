local M = {}

---@param bufnr integer
---@param line_num? integer
---@return { path: string, name: string } | nil
local function get_line(bufnr, line_num)
    line_num = line_num or vim.api.nvim_win_get_cursor(0)[1]
    local line = vim.api.nvim_buf_get_lines(bufnr, line_num - 1, line_num, false)[1]
    if line == "" then
        return nil
    end
    local path = line:match("󰌹%s+(%S+)")
    return { path = path, name = vim.fs.basename(path) }
end

---@param command_builder trunks.Command
---@return string[]
local function get_lines(command_builder)
    local worktrees = require("trunks._core.run_cmd").run_cmd(command_builder)
    local output = {}
    local cwd = vim.fn.getcwd()
    for _, line in ipairs(worktrees) do
        local worktree_path = line:match("^%S+")
        local is_current_worktree = worktree_path == cwd
        if is_current_worktree then
            table.insert(output, string.format(" *  󰌹  %s", line))
        else
            table.insert(output, string.format("    󰌹  %s", line))
        end
    end
    return output
end

local function highlight(bufnr)
    local hlgroups = require("trunks._constants.highlight_groups").highlight_groups
    for i, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
        local star_start, star_end = line:find("*", 1, true)
        require("trunks._ui.highlight").highlight_line(bufnr, hlgroups.TRUNKS_DIFF_ADD, i - 1, star_start, star_end)
        local path_start, path_end = line:find("[^/]*[^%s]*$", 9)
        if not path_start or not path_end then
            return
        end
        require("trunks._ui.highlight").highlight_line(bufnr, "Special", i - 1, path_start, path_end)
        local hash_start, hash_end = line:find("%s(%x+)", path_start)
        require("trunks._ui.highlight").highlight_line(bufnr, "MatchParen", i - 1, hash_start, hash_end)
    end
end

---@param bufnr integer
---@param command_builder trunks.Command
local function set_lines(bufnr, command_builder)
    vim.bo[bufnr].modifiable = true
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, get_lines(command_builder))
    vim.bo[bufnr].modifiable = false
    highlight(bufnr)
end

---@param bufnr integer
---@param command_builder trunks.Command
local function set_keymaps(bufnr, command_builder)
    local keymap_opts = { noremap = true, silent = true, buffer = bufnr, nowait = true }
    local keymaps = require("trunks._ui.keymaps.base").get_keymaps(bufnr, "worktree", {})
    local set = require("trunks._ui.keymaps.set").safe_set_keymap

    set("n", keymaps.create, function()
        local ok, line_data = pcall(get_line, bufnr)
        if not ok or not line_data then
            return
        end

        local parent_dir = vim.fn.fnamemodify(vim.fn.getcwd(), ":h") .. "/"
        vim.ui.input({
            prompt = "Create worktree: ",
            default = parent_dir,
        }, function(input)
            if not input then
                return
            end
            vim.ui.select(
                require("trunks._completion.completion").get_branches(),
                { prompt = "Branch for new worktree" },
                function(worktree_branch)
                    if not worktree_branch then
                        return
                    end
                    vim.cmd(string.format("G worktree add %s %s", input, worktree_branch))
                end
            )
        end)
    end, keymap_opts)

    set("n", keymaps.delete, function()
        require("trunks._core.async").run_async(function()
            local ok, line_data = pcall(get_line, bufnr)
            if not ok or not line_data then
                return
            end
            if
                require("trunks._ui.utils.confirm").confirm_choice(
                    "Are you sure you want to delete worktree " .. line_data.name .. "?"
                )
            then
                vim.cmd(string.format("G worktree remove %s", line_data.name))
            end
        end)
    end, keymap_opts)

    set("n", keymaps.switch, function()
        local ok, line_data = pcall(get_line, bufnr)
        if not ok or not line_data then
            return
        end

        -- Get the git directory for the worktree
        local git_dir = vim.fn
            .system(string.format("git -C %s rev-parse --git-dir", vim.fn.shellescape(line_data.path)))
            :gsub("\n", "")

        -- Set the new GIT_DIR and GIT_WORK_TREE environment variables
        vim.env.GIT_DIR = git_dir
        vim.env.GIT_WORK_TREE = line_data.path
        vim.api.nvim_set_current_dir(line_data.path)

        set_lines(bufnr, command_builder)
    end, keymap_opts)
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

    highlight(bufnr)
    set_keymaps(bufnr, command_builder)

    require("trunks._core.register").register_buffer(bufnr, {
        render_fn = function()
            set_lines(bufnr, command_builder)
        end,
    })
end

return M
