local M = {}

local run_cmd = require("trunks._core.run_cmd").run_cmd

---Resolve a single ref to a commit hash
---@param ref string
---@return string | nil
local function resolve_ref(ref)
    local result = run_cmd("rev-parse --verify " .. vim.fn.shellescape(ref) .. " 2>/dev/null")
    if result and result[1] and result[1]:match("^%x+$") then
        return result[1]
    end
    return nil
end

---Resolve two refs to commit hashes
---@param ref1 string
---@param ref2 string
---@return { from: string, to: string } | nil
local function resolve_refs(ref1, ref2)
    local from = resolve_ref(ref1)
    local to = resolve_ref(ref2)

    if from and to then
        return { from = from, to = to }
    end
    return nil
end

---Resolve refs using merge-base for triple-dot notation
---@param ref1 string
---@param ref2 string
---@return { from: string, to: string } | nil
local function resolve_refs_with_merge_base(ref1, ref2)
    local to = resolve_ref(ref2)
    if not to then
        return nil
    end

    -- Get merge-base for ref1...ref2
    local result =
        run_cmd("merge-base " .. vim.fn.shellescape(ref1) .. " " .. vim.fn.shellescape(ref2) .. " 2>/dev/null")
    if result and result[1] and result[1]:match("^%x+$") then
        return { from = result[1], to = to }
    end

    return nil
end

---Parse a git diff command to extract the refs being compared
---@param cmd string The full git command
---@return { from: string, to: string } | nil refs The resolved commit hashes, or nil if parsing fails
function M.parse_diff_refs(cmd)
    -- Extract just the arguments after "git diff"
    local diff_start = cmd:find("diff")
    if not diff_start then
        return nil
    end

    -- Get everything after "git diff" (or just "diff")
    local args_str = cmd:sub(diff_start + 4):gsub("^%s+", "")

    -- Filter out common flags and options to get just the refs
    local args = {}
    local skip_next = false
    for arg in args_str:gmatch("%S+") do
        if skip_next then
            skip_next = false
        elseif arg:match("^%-%-") then
            -- Long options that take values
            -- luacheck: ignore
            if arg:match("^%-%-unified=") or arg:match("^%-%-diff%-filter=") then
                -- Option has value inline, don't skip next
            elseif arg == "--unified" or arg == "--diff-filter" or arg == "--color" then
                skip_next = true
            end
            -- Otherwise ignore the flag
            -- luacheck: ignore
        elseif arg:match("^%-") and not arg:match("^%-%-") then
            -- Short options, ignore (e.g., -U3, -p, --cached)
            -- But don't skip next since short opts with values are inline
        else
            -- This looks like a ref
            table.insert(args, arg)
        end
    end

    -- Now we have potential refs in args
    -- Handle different cases:

    if #args == 0 then
        -- "git diff" - working tree vs index
        -- We can't really map this to commits easily, so return nil
        return nil
    elseif #args == 1 then
        local ref = args[1]

        -- Check for double-dot notation: ref1..ref2
        local ref1, ref2 = ref:match("^(.+)%.%.(.+)$")
        if ref1 and ref2 then
            return resolve_refs(ref1, ref2)
        end

        -- Check for triple-dot notation: ref1...ref2
        ref1, ref2 = ref:match("^(.+)%.%.%.(.+)$")
        if ref1 and ref2 then
            -- For triple-dot, we need merge-base
            return resolve_refs_with_merge_base(ref1, ref2)
        end

        -- Single ref: comparing working tree/index to ref
        -- Return nil as "from" since working tree isn't a commit
        local resolved = resolve_ref(ref)
        if resolved then
            return { from = nil, to = resolved }
        end
        return nil
    elseif #args >= 2 then
        -- "git diff ref1 ref2" - two refs
        local ref1, ref2 = args[1], args[2]
        return resolve_refs(ref1, ref2)
    end

    return nil
end

return M
