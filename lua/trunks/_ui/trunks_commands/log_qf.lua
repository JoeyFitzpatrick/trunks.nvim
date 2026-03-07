local M = {}

---Update the tracked filepath when a git --summary rename/copy line is encountered.
---Mirrors fugitive's LogParse rename-tracking logic.
---@param line string
---@param target string current target path (relative to git root, no leading slash)
---@return string updated target
local function apply_rename(line, target)
    local rename = line:match("^ rename (.*) %(%d+%%%)") or line:match("^ copy (.*) %(%d+%%%)")
    if not rename then
        return target
    end
    -- Normalize plain "old => new" to "{old => new}"
    if not rename:find("{", 1, true) then
        rename = "{" .. rename .. "}"
    end
    -- Extract new path: replace {old => new} block with new part, preserving surrounding path
    local new_path = rename:gsub("{(.-) => (.-)}", "%2")
    local old_path = rename:gsub("{(.-) => (.-)}", "%1")
    if target == new_path then
        return old_path
    end
    return target
end

---@param input_args vim.api.keyset.create_user_command.command_args
function M.render(input_args)
    local args = input_args.args:match("^log%-qf%s*(.*)")
    args = args and vim.trim(args) or ""
    if args ~= "" then
        args = require("trunks._core.parse_command").expand_special_characters(args)
    end

    local line1 = input_args.line1
    local line2 = input_args.line2

    -- range == 2: explicit two-address range (e.g. :'<,'>), use -L mode
    -- range == 1: single address (e.g. :0Trunks), use whole-file follow mode
    -- range == 0: no range given, show all commits without file context
    local use_L_range = input_args.range == 2
    local follow = input_args.range == 1

    local current_file = vim.fn.expand("%:p")
    local git_root = require("trunks._core.parse_command")._find_git_root(current_file)
    if not git_root then
        vim.notify("Trunks log-qf: not in a git repository", vim.log.levels.ERROR)
        return
    end

    -- filepath relative to git root (populated only when a range/file context is given)
    local filepath = nil

    if use_L_range or follow then
        if current_file == "" then
            vim.notify("Trunks log-qf: no file in current buffer", vim.log.levels.ERROR)
            return
        end
        filepath = current_file:sub(#git_root + 2)
    end

    local cmd_parts = {
        "git",
        "-C",
        vim.fn.shellescape(git_root),
        "--no-pager",
        "log",
        "--pretty=tformat:%H%x09%h%x09%s",
    }

    if use_L_range then
        -- Combined -L arg avoids shell-quoting the colon separator
        local l_arg = string.format("-L%d,%d:%s", line1, line2, filepath)
        table.insert(cmd_parts, vim.fn.shellescape(l_arg))
    end

    if follow then
        table.insert(cmd_parts, "--follow")
        table.insert(cmd_parts, "--summary")
    end

    if args ~= "" then
        table.insert(cmd_parts, args)
    end

    if filepath and not use_L_range then
        table.insert(cmd_parts, "--")
        table.insert(cmd_parts, vim.fn.shellescape(filepath))
    end

    local cmd = table.concat(cmd_parts, " ")
    local lines = vim.fn.systemlist(cmd)
    local exit_code = vim.v.shell_error

    if exit_code ~= 0 then
        vim.notify("Trunks log-qf: " .. table.concat(lines, "\n"), vim.log.levels.ERROR)
        return
    end

    local vb = require("trunks._core.virtual_buffers")
    local qf_items = {}
    -- For whole-file follow mode: tracks the filepath backwards through renames
    local current_target = filepath

    -- For -L mode: buffers commit info until +++ gives the actual path and @@ gives the lnum
    local pending = nil

    local function flush_pending()
        if not pending then
            return
        end
        local entry_path = pending.path or current_target
        table.insert(qf_items, {
            filename = vb.create_uri(git_root, pending.hash, entry_path),
            module = pending.short_hash .. ":" .. entry_path,
            lnum = pending.lnum,
            text = pending.subject,
            valid = 1,
        })
        pending = nil
    end

    for _, line in ipairs(lines) do
        -- Commit header line: <40-hex-hash><TAB><short-hash><TAB><subject>
        local tab1 = line:find("\t")
        local is_commit = false
        if tab1 then
            local hash = line:sub(1, tab1 - 1)
            if #hash == 40 and hash:match("^%x+$") then
                is_commit = true
                if use_L_range then
                    flush_pending()
                end

                local rest = line:sub(tab1 + 1)
                local tab2 = rest:find("\t")
                local short_hash, subject
                if tab2 then
                    short_hash = rest:sub(1, tab2 - 1)
                    subject = rest:sub(tab2 + 1)
                else
                    short_hash = hash:sub(1, 7)
                    subject = rest
                end

                if use_L_range then
                    pending = { hash = hash, short_hash = short_hash, subject = subject }
                else
                    local uri, module_str
                    if current_target then
                        uri = vb.create_uri(git_root, hash, current_target)
                        module_str = short_hash .. ":" .. current_target
                    else
                        uri = vb.create_show_uri(git_root, hash)
                        module_str = short_hash
                    end
                    table.insert(qf_items, {
                        filename = uri,
                        module = module_str,
                        text = subject,
                        valid = 1,
                    })
                end
            end
        end

        if not is_commit then
            if use_L_range and pending then
                -- "+++ b/path" gives the actual filepath at this commit (handles renames)
                if not pending.path then
                    local plus_path = line:match("^%+%+%+ b/(.+)$")
                    if plus_path then
                        pending.path = plus_path
                    end
                -- "@@ -x,y +<lnum>,z @@" gives the line to jump to; emit the entry
                elseif not pending.lnum then
                    local lnum_str = line:match("^@+ .-%+(%d+)")
                    if lnum_str then
                        pending.lnum = tonumber(lnum_str)
                        flush_pending()
                    end
                end
            elseif follow and current_target then
                -- Track filepath backwards through renames from git --summary output
                current_target = apply_rename(line, current_target)
            end
        end
    end

    flush_pending()

    if #qf_items == 0 then
        vim.notify("Trunks log-qf: no commits found", vim.log.levels.WARN)
        return
    end

    vim.fn.setqflist({}, "r", {
        title = "Trunks log-qf",
        items = qf_items,
    })
    vim.cmd("copen")
end

return M
