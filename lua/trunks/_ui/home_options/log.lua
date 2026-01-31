local M = {}

local Command = require("trunks._core.command")

---@param bufnr integer
---@param line_num? integer
---@return { hash: string } | nil
local function get_line(bufnr, line_num)
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

M.GIT_FILETYPE_OPTIONS = {
    "-p",
    "-L",
    "--encoding",
}

M.OVERRIDE_DEFAULT_FORMAT_OPTIONS = {
    "--pretty",
    "--format",
    "--oneline",
}

---@param command_builder? trunks.Command
---@return { cmd: string, use_git_filetype_keymaps: boolean }
function M._parse_log_cmd(command_builder, format)
    -- if command has no args, the default command is "git log" with special format
    local command_has_no_args = not command_builder or not command_builder.base or command_builder.base:match("log%s-$")

    if command_has_no_args then
        command_builder = Command.base_command("log"):add_args(format)
        return { cmd = command_builder:build(), use_git_filetype_keymaps = false }
    end

    local git_filetype_output = { cmd = command_builder:build(), use_git_filetype_keymaps = true }
    local args = command_builder.base
    local has_options = require("trunks._core.texter").has_options
    if has_options(args, M.GIT_FILETYPE_OPTIONS) then
        return git_filetype_output
    end

    if not has_options(args, M.OVERRIDE_DEFAULT_FORMAT_OPTIONS) then
        command_builder:add_post_command_args("log", format)
    end

    return { cmd = command_builder:build(), use_git_filetype_keymaps = false }
end

---@param bufnr integer
local function set_keymaps(bufnr)
    local keymaps = require("trunks._ui.keymaps.base").get_keymaps(bufnr, "log", {})
    local keymap_opts = { noremap = true, silent = true, buffer = bufnr, nowait = true }
    local set = require("trunks._ui.keymaps.set").safe_set_keymap

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
        vim.cmd("G diff " .. line_data.hash)
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
        vim.cmd("G rebase -i " .. line_data.hash)
    end, keymap_opts)

    set("n", keymaps.reset, function()
        local ok, line_data = pcall(get_line, bufnr)
        if not ok or not line_data then
            return
        end
        vim.ui.select({ "mixed", "soft", "hard" }, { prompt = "Git reset type: " }, function(selection)
            require("trunks._core.run_cmd").run_hidden_cmd("git reset --" .. selection .. " " .. line_data.hash)
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
function M.set_lines(bufnr, opts)
    local cmd_tbl = M._parse_log_cmd(opts.command_builder, log_format)
    require("trunks._ui.elements").terminal(bufnr, cmd_tbl.cmd, { enter = true, display_strategy = "full" })
    return cmd_tbl
end

---@param bufnr integer
---@param opts trunks.UiRenderOpts
function M.render(bufnr, opts)
    local cmd_tbl = M.set_lines(bufnr, opts)

    if cmd_tbl.use_git_filetype_keymaps then
        require("trunks._ui.keymaps.git_filetype_keymaps").set_keymaps(bufnr)
    else
        set_keymaps(bufnr)
    end
    if opts.set_keymaps then
        opts.set_keymaps(bufnr)
    end

    local ui_types = { "log" }
    if opts.set_keymaps then
        table.insert(ui_types, 1, "home")
    end

    require("trunks._ui.keymaps.keymaps_text").show_in_cmdline(bufnr, ui_types)

    require("trunks._core.autocmds").execute_user_autocmds({ ui_type = "buffer", ui_name = "log" })
end

return M
