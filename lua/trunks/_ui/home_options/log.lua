local M = {}

---@param bufnr integer
---@param line_num? integer
---@return { hash: string } | nil
local function base_get_line(bufnr, line_num)
    line_num = line_num or vim.api.nvim_win_get_cursor(0)[1]
    local line = vim.api.nvim_buf_get_lines(bufnr, line_num - 1, line_num, false)[1]
    if line == "" then
        return nil
    end
    if line:match("^%a+:") then
        return { hash = line:match(": (%S+)") }
    end
    return { hash = line:match("%w+") }
end

vim.tbl_get(require("trunks._core.configuration"), "DATA", "log", "default_format")
local log_format = vim.tbl_get(require("trunks._core.configuration"), "DATA", "log", "default_format") or ""

M.NATIVE_OUTPUT_OPTIONS = {
    "-p",
    "-L",
    "--pretty",
    "--format",
    "--encoding",
}

---@param command string
---@param option string
---@return boolean
local function contains_option(command, option)
    return command:match("%s+" .. option:gsub("%-", "%-"))
end

---@param command_builder? trunks.Command
---@return { cmd: string, use_native_output: boolean, show_head: boolean }
function M._parse_log_cmd(command_builder)
    -- if command has no args, the default command is "git log" with special format
    if not command_builder then
        command_builder = require("trunks._core.command").base_command("log"):add_args(log_format)
        return { cmd = command_builder:build(), use_native_output = false, show_head = true }
    end

    local args = command_builder.base
    if not args or args:match("log%s-$") then
        command_builder:add_args(log_format)
        return { cmd = command_builder:build(), use_native_output = false, show_head = true }
    end

    local native_output = { cmd = command_builder:build(), use_native_output = true, show_head = false }
    for _, option in ipairs(M.NATIVE_OUTPUT_OPTIONS) do
        if contains_option(args, option) then
            return native_output
        end
    end

    local args_without_log_prefix = args:sub(5)
    local cmd_with_format = string.format("git log %s %s", log_format, args_without_log_prefix)

    -- This checks whether a flag that starts with "-" is present
    -- If not, we're probably just using log on a branch or commit,
    -- so showing the branch being logged is desired.
    local show_head = false
    if not args:match("^log.-%s%-") then
        show_head = true
    end
    return { cmd = cmd_with_format, use_native_output = false, show_head = show_head }
end

---@param bufnr integer
---@param line_num integer | nil
---@return string | nil
local function get_log_branch(bufnr, line_num)
    if not line_num then
        return nil
    end
    local line = vim.api.nvim_buf_get_lines(bufnr, line_num, line_num + 1, false)[1]
    if not line then
        return nil
    end
    local branch_name = line:match("Branch: (%S+)")
    return branch_name
end

---@class trunks.LogConfirmCommandParams
---@field cmd string
---@field command_name string
---@field current_branch string | nil
---@field log_branch string | nil

---@param params trunks.LogConfirmCommandParams
local function confirm_command(params)
    local current_branch = params.current_branch
    local log_branch = params.log_branch
    local command_name = params.command_name:gsub("_", " ")
    if current_branch and log_branch and current_branch ~= log_branch then
        if
            require("trunks._ui.utils.confirm").confirm_choice(
                string.format(
                    "Current branch is %s, but viewing log for %s. Are you sure you want to %s?",
                    current_branch,
                    log_branch,
                    command_name
                )
            )
        then
            vim.cmd(params.cmd)
        end
    else
        vim.cmd(params.cmd)
    end
end

---@param bufnr integer
---@param get_line fun(bufnr: integer, line_num?: integer): { hash: string } | nil
---@param opts trunks.UiRenderOpts
local function set_keymaps(bufnr, get_line, opts)
    local keymaps = require("trunks._ui.keymaps.base").get_keymaps(bufnr, "log", {})
    local keymap_opts = { noremap = true, silent = true, buffer = bufnr, nowait = true }
    local set = require("trunks._ui.keymaps.set").safe_set_keymap
    local log_branch = get_log_branch(bufnr, opts.start_line)
    local current_branch = require("trunks._core.run_cmd").run_cmd("branch --show-current")[1]

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

    set("n", keymaps.checkout, function()
        local ok, line_data = pcall(get_line, bufnr)
        if not ok or not line_data then
            return
        end
        vim.cmd("G checkout " .. line_data.hash)
    end, keymap_opts)

    set("n", keymaps.commit_details, function()
        local ok, line_data = pcall(get_line, bufnr)
        if not ok or not line_data then
            return
        end
        require("trunks._ui.commit_details").render(line_data.hash, {})
    end, keymap_opts)

    set("n", keymaps.diff_commit_against_head, function()
        local ok, line_data = pcall(get_line, bufnr)
        if not ok or not line_data then
            return
        end
        vim.cmd("G difftool " .. line_data.hash)
    end, keymap_opts)

    set("n", keymaps.commit_drop, function()
        local ok, line_data = pcall(get_line, bufnr)
        if not ok or not line_data then
            return
        end
        if
            require("trunks._ui.utils.confirm").confirm_choice(
                "Are you sure you want to drop commit " .. line_data.hash .. "?"
            )
        then
            vim.cmd("Trunks commit-drop " .. line_data.hash)
        end
    end, keymap_opts)

    set("n", keymaps.rebase, function()
        local ok, line_data = pcall(get_line, bufnr)
        if not ok or not line_data then
            return
        end
        confirm_command({
            cmd = "G rebase -i ",
            command_name = "rebase",
            current_branch = current_branch,
            log_branch = log_branch,
        })
    end, keymap_opts)

    set("n", keymaps.reset, function()
        local ok, line_data = pcall(get_line, bufnr)
        if not ok or not line_data then
            return
        end
        vim.ui.select({ "mixed", "soft", "hard" }, { prompt = "Git reset type: " }, function(selection)
            require("trunks._core.run_cmd").run_hidden_cmd("git reset --" .. selection .. " " .. line_data.hash)
            M.set_lines(bufnr, opts)
        end)
    end, keymap_opts)

    set("n", keymaps.revert, function()
        local ok, line_data = pcall(get_line, bufnr)
        if not ok or not line_data then
            return
        end
        require("trunks._core.run_cmd").run_hidden_cmd("git revert " .. line_data.hash .. " --no-commit")
        if vim.v.shell_error == 0 then
            vim.notify("Reverted commit " .. line_data.hash .. " and staged changes")
            require("trunks._core.run_cmd").run_hidden_cmd("git revert --quit")
        end
    end, keymap_opts)

    set("n", keymaps.revert_and_commit, function()
        local ok, line_data = pcall(get_line, bufnr)
        if not ok or not line_data then
            return
        end
        vim.cmd("G revert " .. line_data.hash)
        if vim.v.shell_error == 0 then
            vim.notify("Reverted commit " .. line_data.hash)
        end
    end, keymap_opts)

    set("n", keymaps.show, require("trunks._ui.keymaps.base").git_show_keymap_fn(bufnr, get_line), keymap_opts)
end

---@param bufnr integer
---@param opts trunks.UiRenderOpts
function M.render(bufnr, opts)
    local cmd_tbl = M._parse_log_cmd(opts.command_builder)
    require("trunks._ui.elements").terminal(bufnr, cmd_tbl.cmd, { enter = true, display_strategy = "full" })

    if cmd_tbl.use_native_output then
        require("trunks._ui.keymaps.git_filetype_keymaps").set_keymaps(bufnr)
    else
        local get_line_fn = base_get_line
        set_keymaps(bufnr, get_line_fn, opts)
    end
    if opts.set_keymaps then
        opts.set_keymaps(bufnr)
    end
    require("trunks._core.autocmds").execute_user_autocmds({ ui_type = "buffer", ui_name = "log" })
end

return M
