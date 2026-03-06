local M = {}

---@param input string
---@return string
function M.expand_special_characters(input)
    -- Mirrors fugitive's expand logic: expands %, #, <cword>, etc. with optional
    -- modifier flags (:p, :h, etc.) and :S for shellescape, while leaving
    -- quoted strings unexpanded.
    -- submatch(1)=quoted string, submatch(2)=var, submatch(3)=flags,
    -- submatch(4)=inner flag group (unused), submatch(5)=:S
    local var = [[\%(<\%(cword\|cWORD\|cexpr\|cfile\|sfile\|slnum\|afile\|abuf\|amatch\)>\|%\|#<\=\d\+\|##\=\)]]
    local flag = [[\%(:[p8~.htre]\|:g\=s\(.\).\{-\}\1.\{-\}\1\)]]
    local quoted = [[\('\%(''\|[^']\)*'\|"\%([^"]\|""\|\\"\)*"\)]]
    local pattern = quoted .. [[\|\(]] .. var .. [[\)\(]] .. flag .. [=[*\)\(:S\)\=]=]
    local repl = [[\=empty(submatch(1)) ? (empty(submatch(5)) ? expand(submatch(2).submatch(3)) : ]]
        .. [[shellescape(expand(submatch(2).submatch(3)))) : ]]
        .. [[submatch(1)]]
    return vim.fn.substitute(input, pattern, repl, "g")
end

---@param cmd string
---@param input_args vim.api.keyset.create_user_command.command_args
---@return string
local function parse_visual_command(cmd, input_args)
    if cmd:match("^log %-L") then
        return cmd:gsub(
            "^log %-L",
            "log -L " .. input_args.line1 .. "," .. input_args.line2 .. ":" .. vim.api.nvim_buf_get_name(0)
        )
    end

    if cmd:match("^log %-S") then
        local replacement = string.format("log -S '%s' -w", require("trunks._ui.utils.ui_utils").get_visual_selection())
        return cmd:gsub("^log %-S", replacement)
    end
    return cmd
end

---@type table<string, fun(cmd: string): string>
local subcommand_parsers = {
    switch = function(cmd)
        if cmd:match("switch%s%S+$") then
            local parsed_cmd, _ = cmd:gsub("origin/", "", 1)
            return parsed_cmd
        end
        return cmd
    end,
}

--- Parsing rules for subcommands. For instance, if `:G switch origin/some-branch`
--- is invoked with no options, remove 'origin/' from the branch to switch to.
---
--- If there is no parser for the given subcommand, just return the command.
---@param cmd string
---@return string
local function parse_subcommand(cmd)
    local subcommand = cmd:match("^%S+")
    if not subcommand then
        return cmd
    end
    local parser = subcommand_parsers[subcommand]
    if not parser then
        return cmd
    end
    return parser(cmd)
end

---@param filepath string
---@return boolean
local function is_in_cwd(filepath)
    local cwd = vim.loop.cwd()
    if not cwd then
        return false
    end
    return vim.startswith(filepath, cwd .. "/") or filepath == cwd
end

---@param path string
---@return string | nil
function M._find_git_root(path)
    local uv = vim.loop
    local function exists(p)
        local stat = uv.fs_stat(p)
        return stat ~= nil
    end
    path = vim.fn.fnamemodify(path, ":p")
    while path and path ~= "/" do
        local git_dir = path .. "/.git"
        if exists(git_dir) then
            return path
        end
        path = vim.fn.fnamemodify(path, ":h")
    end
    return nil
end

---@param path? string
---@return string | nil
function M.get_git_c_flag(path)
    if not path then
        local buffer_to_check
        if not vim.b.is_trunks_buffer then
            buffer_to_check = vim.api.nvim_get_current_buf()
        else
            buffer_to_check =
                require("trunks._core.register").last_non_trunks_buffer_for_win[vim.api.nvim_get_current_win()]
        end
        if not buffer_to_check or not vim.api.nvim_buf_is_valid(buffer_to_check) then
            return nil
        end

        path = vim.api.nvim_buf_get_name(buffer_to_check or 0)
    end

    if path == "" then
        return nil
    end

    -- If path is "%", expand it to filename
    path = M.expand_special_characters(path)

    if is_in_cwd(path) then
        return nil
    else
        local git_root = M._find_git_root(path)
        if git_root then
            return "-C " .. vim.fn.shellescape(git_root)
        end
    end
    return nil
end

--- Expand `%` to current file.
--- Also modify command in some special cases.
---@param input_args vim.api.keyset.create_user_command.command_args
---@return string
M.parse = function(input_args)
    local parsed_cmd = M.expand_special_characters(input_args.args)
    parsed_cmd = parse_subcommand(parsed_cmd)

    if require("trunks._ui.utils.ui_utils").is_visual_command(input_args) then
        parsed_cmd = parse_visual_command(parsed_cmd, input_args)
    end
    return parsed_cmd
end

--- When the current buffer is outside the cwd, use the current
--- buffer's .git as the git dir for the command (if it exists).
---@param cmd string
---@return string
function M.add_git_dir_flag(cmd)
    local git_dir_c_flag = M.get_git_c_flag()
    if git_dir_c_flag then
        return git_dir_c_flag .. " " .. cmd
    end
    return cmd
end

return M
