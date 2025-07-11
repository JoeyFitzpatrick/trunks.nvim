local PULL_DESCRIPTION = "Pull changes"
local PUSH_DESCRIPTION = "Push changes"

local M = {}

M.long_descriptions = {
    ---@type trunks.HomeKeymaps
    home = {
        next = "Move to next item",
        previous = "Move to previous item",
    },
    ---@type trunks.AutoDisplayKeymaps
    auto_display = {
        scroll_diff_down = "Scroll auto-display window down",
        scroll_diff_up = "Scroll auto-display window up",
        toggle_auto_display = "Toggle auto-display window",
    },
    ---@type trunks.BlameKeymaps
    blame = {
        checkout = "Checkout commit (with detached HEAD)",
        commit_details = "Show commit details",
        commit_info = "Show commit info",
        diff_file = "Display file diff",
        reblame = "Reblame file at commit",
        return_to_original_file = "Close blame and return to original file",
        show = "Show commit details",
    },
    ---@type trunks.BranchKeymaps
    branch = {
        delete = "Delete branch",
        log = "Show branch log",
        new_branch = "Create new branch",
        pull = PULL_DESCRIPTION,
        push = PUSH_DESCRIPTION,
        rename = "Rename branch",
        spinoff = "Spinoff branch",
        switch = "Switch branch",
    },
    ---@type trunks.CommitDetailsKeymaps
    commit_details = {
        show_all_changes = "Show all changes from this commit in a single buffer",
    },
    ---@type trunks.CommitPopupKeymaps
    commit_popup = {
        commit = "Regular commit",
        commit_amend = "Amend commit",
        commit_amend_reuse_message = "Amend commit reusing message",
        commit_dry_run = "Run dry run commit",
        commit_no_verify = "Commit with --no-verify to skip pre-commit hooks",
    },
    ---@type trunks.DiffKeymaps
    diff = {
        next_hunk = "Move to next hunk",
        previous_hunk = "Move to previous hunk",
        stage = "Stage hunk under cursor or visually selected lines",
    },
    ---@type trunks.GitFiletypeKeymaps
    git_filetype = {
        show_details = "Show details for item under cursor",
    },
    ---@type trunks.LogKeymaps
    log = {
        checkout = "Checkout commit (with detached HEAD)",
        commit_details = "Show commit details",
        commit_info = "Show commit info",
        diff_commit_against_head = "Diff commit against current HEAD",
        pull = PULL_DESCRIPTION,
        push = PUSH_DESCRIPTION,
        rebase = "Rebase",
        reset = "Reset",
        revert = "Revert commit, and stage the changes from the revert",
        revert_and_commit = "Revert commit, and commit the revert",
        show = "Show commit details",
    },
    ---@type trunks.OpenFilesKeymaps
    open_files = {
        open_in_current_window = "Open file at this commit in current window",
        open_in_horizontal_split = "Open file at this commit in a horizontal split",
        open_in_new_tab = "Open file at this commit in a new tab",
        open_in_vertical_split = "Open file at this commit in a vertical split",
    },
    ---@type trunks.ReflogKeymaps
    reflog = {
        checkout = "Checkout commit (with detached HEAD)",
        commit_details = "Show commit in Trunks commit details UI",
        commit_info = "Show commit info",
        recover = "Recover this commit by making a branch from it",
        show = "Show commit details (native diff)",
    },
    ---@type trunks.StashKeymaps
    stash = {
        apply = "Apply stash",
        drop = "Drop stash",
        pop = "Pop stash",
        show = "Show stash",
    },
    ---@type trunks.StashPopupKeymaps
    stash_popup = {
        stash_all = "Stash all changes",
        stash_staged = "Stash staged changes",
    },
    ---@type trunks.StatusKeymaps
    status = {
        commit_popup = "Open git commit options",
        diff_file = "Diff file",
        edit_file = "Edit file",
        enter_staging_area = "Enter staging area (stage hunks/lines)",
        pull = PULL_DESCRIPTION,
        push = PUSH_DESCRIPTION,
        restore = "Open git restore options, or restore visually selected lines",
        stage = "Stage file",
        stage_all = "Stage all files",
        stash_popup = "Open git stash options",
    },
    worktree = {
        create = "Create new worktree",
        delete = "Delete worktree",
        switch = "Switch to worktree",
    },
}

local config = require("trunks._core.configuration").DATA

local function is_empty(str)
    return str == nil or str == ""
end

---@param ui_type string
---@param map_name string
---@param desc string
local function add_description(ui_type, map_name, desc)
    local lhs = config[ui_type].keymaps[map_name]
    if is_empty(lhs) then
        return
    end

    M.short_descriptions[ui_type] = M.short_descriptions[ui_type] or {}
    table.insert(M.short_descriptions[ui_type], lhs .. " " .. desc)
end

M.short_descriptions = {}

---@type trunks.Configuration
M.short_descriptions = {}

if not is_empty(config.home.keymaps.previous) and not is_empty(config.home.keymaps.next) then
    M.short_descriptions.home =
        { string.format("%s/%s Change UI", config.home.keymaps.previous, config.home.keymaps.next) }
end

add_description("status", "commit_popup", "Commit")
add_description("status", "stash_popup", "Stash")
add_description("status", "restore", "Discard")

add_description("branch", "switch", "Switch")
add_description("branch", "new_branch", "New branch")
add_description("branch", "log", "Commits")
add_description("branch", "rename", "Rename")
add_description("branch", "delete", "Delete")

add_description("log", "commit_details", "Details")
add_description("log", "rebase", "Rebase")
add_description("log", "revert", "Revert")
add_description("log", "checkout", "Checkout")
add_description("log", "diff_commit_against_head", "Diff")

add_description("reflog", "checkout", "Checkout")
add_description("reflog", "commit_details", "Details")
add_description("reflog", "recover", "Recover as branch")

add_description("stash", "apply", "Apply")
add_description("stash", "pop", "Pop")
add_description("stash", "drop", "Drop")
add_description("stash", "show", "Details")

---@param ui_types string[]
---@return string
function M.get_short_descriptions_as_string(ui_types)
    local descriptions = {}
    for _, ui_type in ipairs(ui_types) do
        if M.short_descriptions[ui_type] then
            for _, desc in ipairs(M.short_descriptions[ui_type]) do
                table.insert(descriptions, desc)
            end
        end
    end
    table.insert(descriptions, "g? Help")
    return table.concat(descriptions, " | ")
end

return M
