local M = {}

local Command = require("trunks._core.command")

---@class trunks.StatusFiles
---@field staged string[]
---@field unstaged string[]
---@field untracked string[]
---@field unstaged_and_untracked string[]

---@param get_files_fn? fun(): string[]
---@return trunks.StatusFiles
function M.get_status_files(get_files_fn)
    get_files_fn = get_files_fn
        or function()
            local cmd = Command.base_command("status -s"):build()
            local files = require("trunks._core.run_cmd").system(cmd)
            return vim.tbl_filter(function(output_line)
                return output_line ~= ""
            end, files.output)
        end

    local files = get_files_fn()

    local staged = {}
    local unstaged = {}
    local untracked = {}

    for _, file in ipairs(files) do
        local filename = file:sub(4)
        if file:sub(1, 2) == "??" then
            if filename:sub(-1) == "/" then
                local ls_cmd = Command.base_command("ls-files --others --exclude-standard -- " .. filename):build()
                local dir_files = require("trunks._core.run_cmd").run_cmd(ls_cmd)
                for _, dir_file in ipairs(dir_files) do
                    if dir_file ~= "" then
                        table.insert(untracked, "? " .. dir_file)
                    end
                end
            else
                table.insert(untracked, "? " .. filename)
            end
        else
            local first_char = file:sub(1, 1)
            local second_char = file:sub(2, 2)
            if first_char ~= " " then
                table.insert(staged, first_char .. " " .. filename)
            end
            if second_char ~= " " then
                table.insert(unstaged, second_char .. " " .. filename)
            end
        end
    end

    local unstaged_and_untracked = {}
    for _, file in ipairs(unstaged) do
        table.insert(unstaged_and_untracked, file)
    end
    for _, file in ipairs(untracked) do
        table.insert(unstaged_and_untracked, file)
    end

    local result = {
        staged = staged,
        unstaged = unstaged,
        untracked = untracked,
        unstaged_and_untracked = unstaged_and_untracked,
    }

    for _, tbl in pairs(result) do
        table.sort(tbl, function(left, right)
            return left:sub(3) < right:sub(3)
        end)
    end

    return result
end

---@param diff_stat_text? string
---@param callback function
function M.get_diff_stat(diff_stat_text, callback)
    if diff_stat_text then
        callback({ diff_stat_text })
        return
    end
    local diff_stat_cmd = Command.base_command("diff --staged --shortstat"):build({ no_pager = true })
    vim.system(
        {
            "sh",
            "-c",
            diff_stat_cmd,
        },
        vim.schedule_wrap(function(result)
            local output = result.stdout:gsub("\n", "")
            if result.code == 0 and output and output ~= "" then
                callback({ vim.trim(output) })
            else
                callback({ "No staged changes" })
            end
        end)
    )
end

---@param key string
---@param type_flag? string
---@return string?
local function read_config(key, type_flag)
    local trunks_system = require("trunks._core.run_cmd").system
    local arg = type_flag and ("--type=" .. type_flag .. " " .. key) or key
    local cmd = Command.base_command("config " .. arg):build()
    local result = trunks_system(cmd)
    if result.code == 0 and result.output[1] and result.output[1] ~= "" then
        return result.output[1]
    end
    return nil
end

--- Reads the effective `pull.rebase` value for `head`, honoring
--- `branch.<head>.rebase` first then falling back to `pull.rebase`.
--- Returns either "Rebase: " or "Merge: ".
---@param head? string
---@return string
local function resolve_pull_config_prefix(head)
    local value
    if head and head ~= "(detached)" then
        value = read_config(string.format("branch.%s.rebase", head), "bool-or-string")
    end
    if value == nil then
        value = read_config("pull.rebase", "bool-or-string")
    end

    if value and value ~= "false" then
        return "Rebase: "
    end
    return "Merge: "
end

--- Resolves the push remote for `head`, following git's lookup order:
--- branch.<head>.pushRemote -> remote.pushDefault -> branch.<head>.remote -> "origin".
---@param head? string
---@return string
local function resolve_push_remote(head)
    if head and head ~= "(detached)" then
        local remote = read_config(string.format("branch.%s.pushRemote", head))
        if remote then
            return remote
        end
    end
    local default = read_config("remote.pushDefault")
    if default then
        return default
    end
    if head and head ~= "(detached)" then
        local fetch_remote = read_config(string.format("branch.%s.remote", head))
        if fetch_remote then
            return fetch_remote
        end
    end
    return "origin"
end

---@class trunks.StatusData
---@field head? string
---@field hash? string
---@field remote? string
---@field num_commits_to_pull? string
---@field num_commits_to_push? string
---@field pull_config_prefix string
---@field push_remote string

---@param callback fun(data: trunks.StatusData)
function M.get_head_and_remote(callback)
    local cmd = Command.base_command("status --porcelain=v2 --branch"):build()
    vim.system(
        { "sh", "-c", cmd },
        vim.schedule_wrap(function(result)
            local data = {}
            if result.code ~= 0 then
                data.pull_config_prefix = resolve_pull_config_prefix(nil)
                data.push_remote = resolve_push_remote(nil)
                callback(data)
                return
            end

            local lines = vim.split(result.stdout, "\n", { plain = true, trimempty = true })
            for _, line in ipairs(lines) do
                -- Line shape is # branch.head master, need 3rd item
                if vim.startswith(line, "# branch.head") then
                    data.head = vim.split(line, " ", { plain = true, trimempty = true })[3]
                elseif vim.startswith(line, "# branch.upstream") then
                    data.remote = vim.split(line, " ", { plain = true, trimempty = true })[3]
                elseif vim.startswith(line, "# branch.oid") then
                    data.hash = vim.split(line, " ", { plain = true, trimempty = true })[3]:sub(1, 7)
                elseif vim.startswith(line, "# branch.ab") then
                    local num_commits_split = vim.split(line, " ", { plain = true, trimempty = true })
                    -- Each number looks like +2 or -2, need to remove symbol
                    local num_commits_to_pull = num_commits_split[4]:sub(2)
                    local num_commits_to_push = num_commits_split[3]:sub(2)

                    if tonumber(num_commits_to_pull) > 0 then
                        data.num_commits_to_pull = "↓" .. num_commits_to_pull
                    end
                    if tonumber(num_commits_to_push) > 0 then
                        data.num_commits_to_push = "↑" .. num_commits_to_push
                    end
                end
            end

            data.pull_config_prefix = resolve_pull_config_prefix(data.head)
            data.push_remote = resolve_push_remote(data.head)
            callback(data)
        end)
    )
end

---@class trunks.SetStatusFilesVariableParams
---@field files trunks.StatusFiles
---@field unstaged_untracked_index? integer
---@field staged_index? integer

---@class trunks.StatusFilesBufferVariableEntry
---@field status string
---@field staged boolean
---@field expanded boolean

---@class trunks.StatusFilesBufferVariable
---@field staged table<string, trunks.StatusFilesBufferVariableEntry>
---@field unstaged table<string, trunks.StatusFilesBufferVariableEntry>

---@param bufnr integer
---@param opts trunks.SetStatusFilesVariableParams
---@return trunks.StatusFilesBufferVariable
function M.set_status_files_variable(bufnr, opts)
    local trunks_status_files = { staged = {}, unstaged = {} }

    if opts.unstaged_untracked_index then
        for _, file in ipairs(opts.files.unstaged_and_untracked) do
            local filename = file:sub(3)
            trunks_status_files.unstaged[filename] = { status = file:sub(1, 1), staged = false, expanded = false }
        end
    end

    if opts.staged_index then
        for _, file in ipairs(opts.files.staged) do
            local filename = file:sub(3)
            trunks_status_files.staged[filename] = { status = file:sub(1, 1), staged = true, expanded = false }
        end
    end
    vim.b[bufnr].trunks_status_files = trunks_status_files
    return trunks_status_files
end

---@param line_data trunks.StatusLineData
---@return string
function M.get_diff_cmd(line_data)
    local status = line_data.status
    local safe_filename = line_data.safe_filename
    local is_staged = line_data.staged

    local is_untracked = status == "?"
    if is_untracked then
        return "diff --no-index /dev/null -- " .. safe_filename
    end

    if is_staged then
        return "diff --staged -- " .. safe_filename
    end

    local is_modified = status == "M"
    if is_modified then
        return "diff -- " .. safe_filename
    end

    return "diff -- " .. safe_filename
end

---@param bufnr integer
---@param line_num integer
---@param line_data trunks.StatusLineData
---@param run_cmd_fn? fun(cmd: string[]): string[], integer
function M.toggle_inline_diff(bufnr, line_num, line_data, run_cmd_fn)
    run_cmd_fn = run_cmd_fn or require("trunks._core.run_cmd").run_cmd
    local status_files = vim.b[bufnr].trunks_status_files
    local file
    if line_data.staged then
        file = status_files.staged[line_data.filename]
    else
        file = status_files.unstaged[line_data.filename]
    end

    if not file.expanded then
        local cmd = Command.base_command(M.get_diff_cmd(line_data):gsub("^diff", "diff --no-color"))
            :build({ no_pager = true })
        local diff_output, exit_code = run_cmd_fn(cmd)
        if exit_code == 0 or (exit_code == 1 and line_data.status == "?") then
            local start = 1
            for i, line in ipairs(diff_output) do
                if line:match("^@@") then
                    start = i
                    break
                end
            end
            local diff = vim.list_slice(diff_output, start)
            require("trunks._ui.utils.buffer_text").set(bufnr, diff, line_num, line_num)
            file.expanded = true
            vim.b[bufnr].trunks_status_files = status_files
        end
    else
        local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
        local diff_line_pattern = "^[%+%-@ ]"

        -- Walk back until a non-diff line is found
        local diff_start = nil
        while line_num > 0 and not diff_start do
            local line = lines[line_num]
            if not line:match(diff_line_pattern) then
                diff_start = line_num
                break
            end
            line_num = line_num - 1
        end

        -- Walk forward until non-diff line is found

        local diff_end = nil
        line_num = line_num + 1
        while line_num <= #lines and not diff_end do
            local line = lines[line_num]
            if not line:match(diff_line_pattern) then
                diff_end = line_num
                break
            end
            line_num = line_num + 1
        end
        if not diff_end then
            diff_end = line_num
        end

        require("trunks._ui.utils.buffer_text").set(bufnr, {}, diff_start, diff_end - 1)
        file.expanded = false
        vim.b[bufnr].trunks_status_files = status_files
    end
end

return M
