local Command = require("trunks._core.command")

local M = {}

local run_cmd = require("trunks._core.run_cmd")

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
local function set_keymaps(bufnr)
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
            vim.wait(2000, function()
                return not vim.b.trunks_fetch_running
            end)
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
    end, keymap_opts)
end

---@param opts? trunks.UiRenderOpts
function M.render(opts)
    opts = opts or {}
    local command_builder = opts.command_builder or Command.base_command("branch --sort=-HEAD")
    local term =
        require("trunks._ui.elements").terminal(command_builder:build(), { enter = true, display_strategy = "full" })
    local bufnr = term.bufnr
    local win = term.win

    set_keymaps(bufnr)
    require("trunks._core.register").register_buffer(bufnr, {
        render_fn = function()
            M.render()
        end,
    })
    if opts.set_keymaps then
        opts.set_keymaps(bufnr)
    end
    require("trunks._core.autocmds").execute_user_autocmds({ ui_type = "buffer", ui_name = "branch" })
    return bufnr, win
end

return M
