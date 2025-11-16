local Command = require("trunks._core.command")

local M = {}

local run_cmd = require("trunks._core.run_cmd")

--- Highlight branch lines
---@param bufnr integer
---@param start_line integer
---@param lines string[]
local function highlight(bufnr, start_line, lines)
    local highlight_groups = require("trunks._constants.highlight_groups").highlight_groups
    for i, line in ipairs(lines) do
        local line_num = i + start_line - 1
        if line:match("^%*") then
            vim.hl.range(
                bufnr,
                vim.api.nvim_create_namespace(""),
                highlight_groups.TRUNKS_DIFF_ADD,
                { line_num, 2 },
                { line_num, -1 }
            )
        end
    end
    require("trunks._ui.utils.num_commits_pull_push").highlight_num_commits(bufnr, start_line, lines)
end

---@param bufnr integer
---@param opts trunks.UiRenderOpts
local function set_cursor_to_first_branch(bufnr, opts)
    local start_line = opts.start_line or 0
    if opts.win and vim.api.nvim_buf_line_count(bufnr) > start_line then
        vim.api.nvim_win_set_cursor(opts.win, { start_line + 1, 0 })
    end
end

---@param bufnr integer
---@param opts trunks.UiRenderOpts
---@return string[]
local function set_lines(bufnr, opts)
    require("trunks._ui.keymaps.keymaps_text").show(bufnr, opts.ui_types)
    local start_line = opts.start_line or 2
    -- if cmd is nil, the default command is "git branch"
    if not opts.command_builder then
        -- This sorts branches such that the current branch appears first
        opts.command_builder = Command.base_command("branch --sort=-HEAD")
    end
    local output = run_cmd.run_cmd(opts.command_builder)
    vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
    vim.api.nvim_buf_set_lines(bufnr, start_line, -1, false, output)
    vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })

    set_cursor_to_first_branch(bufnr, opts)
    highlight(bufnr, start_line, output)
    require("trunks._ui.utils.num_commits_pull_push").set_num_commits_to_pull_and_push(
        bufnr,
        { highlight = highlight, start_line = start_line, line_type = "branch" }
    )
    return output
end

---@param bufnr integer
---@param line_num? integer
---@return { branch_name: string } | nil
local function get_line(bufnr, line_num)
    line_num = line_num or vim.api.nvim_win_get_cursor(0)[1]
    local line = vim.api.nvim_buf_get_lines(bufnr, line_num - 1, line_num, false)[1]
    if line == "" then
        return nil
    end
    return { branch_name = line:match("%S+", 3) }
end

---@param bufnr integer
---@param opts trunks.UiRenderOpts
local function set_keymaps(bufnr, opts)
    local keymaps = require("trunks._ui.keymaps.base").get_keymaps(bufnr, "branch", {})
    local keymap_opts = { noremap = true, silent = true, buffer = bufnr, nowait = true }
    local set = require("trunks._ui.keymaps.set").safe_set_keymap

    ---@param branch_name string
    ---@param delete_type "local" | "remote" | "both"
    local function delete_branch(branch_name, delete_type)
        local delete_actions = {
            local_only = function()
                return run_cmd.run_hidden_cmd("branch --delete " .. branch_name)
            end,
            remote_only = function()
                return run_cmd.run_hidden_cmd("push origin --delete " .. branch_name)
            end,
            both = function()
                -- Try local deletion first
                local status, code = run_cmd.run_hidden_cmd("branch --delete " .. branch_name)
                if status == "error" then
                    return status, code
                end
                -- Then try remote deletion
                local output, _ = run_cmd.run_hidden_cmd("push origin --delete " .. branch_name)
                return output
            end,
        }
        local action_map = {
            ["local"] = delete_actions.local_only,
            ["remote"] = delete_actions.remote_only,
            ["both"] = delete_actions.both,
        }
        assert(action_map[delete_type], "Attempt to delete branch with invalid delete type: " .. delete_type)
        local status, code = action_map[delete_type]()
        if code == 1 and status == "error" and delete_type ~= "remote" then
            require("trunks._ui.popups.popup").render_popup({
                buffer_name = "TrunksBranchDeleteConfirm",
                title = "Branch "
                    .. require("trunks._core.texter").surround_with_quotes(branch_name)
                    .. " is not fully merged. Delete anyway?",
                mappings = {
                    {
                        keys = "y",
                        description = "Yes",
                        action = function()
                            run_cmd.run_hidden_cmd("branch -D " .. branch_name)
                            set_lines(bufnr, opts)
                        end,
                    },
                    {
                        keys = "n",
                        description = "No",
                        -- This is a no-op, and the popup will close
                        action = function() end,
                    },
                },
            })
        end
        set_lines(bufnr, opts)
    end

    set("n", keymaps.delete, function()
        local ok, line_data = pcall(get_line, bufnr)
        if not ok or not line_data then
            return
        end

        require("trunks._ui.popups.popup").render_popup({
            buffer_name = "TrunksDeleteBranch",
            title = "Delete Branch",
            mappings = {
                {
                    keys = "l",
                    description = "Local",
                    action = function()
                        delete_branch(line_data.branch_name, "local")
                    end,
                },
                {
                    keys = "r",
                    description = "Remote",
                    action = function()
                        delete_branch(line_data.branch_name, "remote")
                    end,
                },
                {
                    keys = "b",
                    description = "Both",
                    action = function()
                        delete_branch(line_data.branch_name, "both")
                    end,
                },
            },
        })
    end, keymap_opts)

    local keymap_to_command_map = {
        { keymap = keymaps.pull, command = "pull" },
        { keymap = keymaps.push, command = "push" },
    }

    for _, mapping in ipairs(keymap_to_command_map) do
        set("n", mapping.keymap, function()
            vim.cmd("G " .. mapping.command)
        end, keymap_opts)
    end

    set("n", keymaps.log, function()
        local ok, line_data = pcall(get_line, bufnr)
        if not ok or not line_data then
            return
        end
        local log_bufnr = require("trunks._ui.elements").new_buffer({ buffer_name = "TrunksLog-" .. os.tmpname() })
        require("trunks._ui.home_options.log").render(
            log_bufnr,
            { start_line = 0, command_builder = Command.base_command("log " .. line_data.branch_name) }
        )
    end, keymap_opts)

    set("n", keymaps.new_branch, function()
        local ok, line_data = pcall(get_line, bufnr)
        if not ok or not line_data then
            return
        end
        vim.ui.input({ prompt = "Name for new branch off of " .. line_data.branch_name .. ": " }, function(input)
            if not input then
                return
            end
            local result = run_cmd.run_hidden_cmd("switch --create " .. input)
            if result == "error" then
                return
            end
            set_lines(bufnr, opts)
        end)
    end, keymap_opts)

    set("n", keymaps.rename, function()
        local ok, line_data = pcall(get_line, bufnr)
        if not ok or not line_data then
            return
        end
        vim.ui.input({ prompt = "New name for branch " .. line_data.branch_name .. ": " }, function(input)
            if not input then
                return
            end
            run_cmd.run_hidden_cmd(string.format("branch -m %s %s", line_data.branch_name, input), { rerender = true })
        end)
    end, keymap_opts)

    set("n", keymaps.spinoff, function()
        local ok, line_data = pcall(get_line, bufnr)
        if not ok or not line_data then
            return
        end
        vim.ui.input({ prompt = "Name for new branch off of " .. line_data.branch_name .. ": " }, function(input)
            if not input then
                return
            end
            -- Create and switch to new branch
            local new_branch_result =
                run_cmd.run_hidden_cmd("switch --create " .. input .. " " .. line_data.branch_name, { rerender = true })
            if new_branch_result == "error" then
                return
            end
            -- Reset previous branch to upstream
            run_cmd.run_hidden_cmd("fetch")
            local upstream_branch =
                run_cmd.run_cmd(string.format("rev-parse --abbrev-ref %s@{upstream}", line_data.branch_name))[1]
            if not upstream_branch then
                return
            end
            run_cmd.run_hidden_cmd(
                string.format("update-ref refs/heads/%s refs/remotes/%s", line_data.branch_name, upstream_branch),
                { rerender = true }
            )
        end)
        set_lines(bufnr, opts)
    end, keymap_opts)

    set("n", keymaps.switch, function()
        local ok, line_data = pcall(get_line, bufnr)
        if not ok or not line_data then
            return
        end
        local result = run_cmd.run_hidden_cmd("switch " .. line_data.branch_name)
        if result == "error" then
            return
        end
        set_lines(bufnr, opts)
    end, keymap_opts)
end

---@param bufnr integer
---@param opts trunks.UiRenderOpts
function M.render(bufnr, opts)
    -- If there's already a buffer named TrunksBranch, just don't set a name
    pcall(vim.api.nvim_buf_set_name, bufnr, "TrunksBranch")

    set_lines(bufnr, opts)
    set_keymaps(bufnr, opts)
    require("trunks._core.autocmds").execute_user_autocmds({ ui_type = "buffer", ui_name = "branch" })
end

return M
