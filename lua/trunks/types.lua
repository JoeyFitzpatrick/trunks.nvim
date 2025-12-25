--- A collection of types to be included / used in other Lua files.
---
--- These types are either required by the Lua API or required for the normal
--- operation of this Lua plugin.
---
---@module 'trunks.types'

---@alias trunks.PagerName "delta" | "diff-so-fancy" | "difft"

---@class trunks.Configuration
---@field prevent_nvim_inception? boolean
---@field pager? trunks.PagerName
---@field auto_display? trunks.AutoDisplayConfiguration
---@field blame? trunks.BlameConfiguration
---@field home? trunks.HomeConfiguration
---@field branch? trunks.BranchConfiguration
---@field commit_details? trunks.CommitDetailsConfiguration
---@field commit_popup? trunks.CommitPopupConfiguration
---@field diff? trunks.DiffConfiguration
---@field difftool? trunks.DifftoolConfiguration
---@field git_filetype? trunks.GitFiletypeConfiguration
---@field log? trunks.LogConfiguration
---@field open_files? trunks.OpenFilesConfiguration
---@field reflog? trunks.ReflogConfiguration
---@field restore_popup? trunks.RestorePopupConfiguration
---@field stash? trunks.StashConfiguration
---@field stash_popup? trunks.StashPopupConfiguration
---@field status? trunks.StatusConfiguration
---@field time_machine? trunks.TimeMachineConfiguration

---@class trunks.BlameConfiguration
---@field keymaps? trunks.BlameKeymaps

---@class trunks.HomeConfiguration
---@field keymaps? trunks.HomeKeymaps

---@class trunks.AutoDisplayConfiguration
---@field keymaps? trunks.AutoDisplayKeymaps

---@class trunks.BranchConfiguration
---@field keymaps? trunks.BranchKeymaps

---@class trunks.CommitDetailsConfiguration
---@field keymaps? trunks.CommitDetailsKeymaps
---@field auto_display_on? boolean

---@class trunks.CommitPopupConfiguration
---@field keymaps? trunks.CommitPopupKeymaps

---@class trunks.DiffConfiguration
---@field keymaps? trunks.DiffKeymaps

---@class trunks.DifftoolConfiguration
---@field auto_display_on? boolean

---@class trunks.GitFiletypeConfiguration
---@field keymaps? trunks.GitFiletypeKeymaps

---@class trunks.LogConfiguration
---@field keymaps? trunks.LogKeymaps
---@field default_format? string

---@class trunks.OpenFilesConfiguration
---@field keymaps? trunks.OpenFilesKeymaps

---@class trunks.ReflogConfiguration
---@field keymaps? trunks.ReflogKeymaps

---@class trunks.StashConfiguration
---@field keymaps? trunks.StashKeymaps
---@field auto_display_on? boolean

---@class trunks.StashPopupConfiguration
---@field keymaps? trunks.StashPopupKeymaps

---@class trunks.StatusConfiguration
---@field keymaps? trunks.StatusKeymaps
---@field auto_display_on? boolean

---@class trunks.TimeMachineConfiguration
---@field auto_display_on? boolean
---@field keymaps? trunks.TimeMachineKeymaps

---@class trunks.HomeKeymaps
---@field next? string
---@field previous? string

---@class trunks.AutoDisplayKeymaps
---@field scroll_diff_down? string
---@field scroll_diff_up? string
---@field toggle_auto_display? string

---@class trunks.BlameKeymaps
---@field checkout? string
---@field diff_file? string
---@field commit_details? string
---@field reblame? string
---@field return_to_original_file? string
---@field show? string

---@class trunks.BranchKeymaps
---@field delete? string
---@field log? string
---@field new_branch? string
---@field pull? string
---@field push? string
---@field rename? string
---@field spinoff? string
---@field switch? string

---@class trunks.CommitDetailsKeymaps
---@field edit_file? string
---@field restore_popup? string
---@field show_all_changes? string

---@class trunks.CommitPopupKeymaps
---@field commit? string
---@field commit_amend? string
---@field commit_amend_reuse_message? string
---@field commit_dry_run? string
---@field commit_no_verify? string
---@field commit_instant_fixup? string

---@class trunks.DiffKeymaps
---@field next_hunk? string
---@field previous_hunk? string
---@field stage? string

---@class trunks.DifftoolKeymaps

---@class trunks.GitFiletypeKeymaps
---@field show_details? string

---@class trunks.LogKeymaps
---@field checkout? string
---@field commit_details? string
---@field diff_commit_against_head? string
---@field commit_drop? string
---@field pull? string
---@field push? string
---@field rebase? string
---@field reset? string
---@field revert? string
---@field revert_and_commit? string
---@field show? string

---@class trunks.OpenFilesKeymaps
---@field open_in_current_window? string
---@field open_in_horizontal_split? string
---@field open_in_new_tab? string
---@field open_in_vertical_split? string

---@class trunks.ReflogKeymaps
---@field checkout? string
---@field commit_details? string
---@field recover? string
---@field show? string

---@class trunks.RestorePopupConfiguration
---@field keymaps? trunks.RestorePopupKeymaps

---@class trunks.RestorePopupKeymaps
---@field restore_from_commit? string
---@field restore_from_commit_before? string

---@class trunks.StashKeymaps
---@field apply? string
---@field drop? string
---@field pop? string
---@field show? string

---@class trunks.StashPopupKeymaps
---@field stash_all? string
---@field stash_staged? string

---@class trunks.StatusKeymaps
---@field commit_popup? string
---@field diff_file? string
---@field edit_file? string
---@field pull? string
---@field push? string
---@field restore? string
---@field stage? string
---@field stage_all? string
---@field stash_popup? string

---@class trunks.TimeMachineKeymaps
---@field commit_details? string
---@field diff_against_previous_commit? string
---@field diff_against_head? string

---@class trunks.TimeMachineFileKeymaps
---@field next? string
---@field previous? string
