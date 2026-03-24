if exists("b:current_syntax")
  finish
endif

syn sync fromstart
syn spell notoplevel

" ── Headers ──────────────────────────────────────────────────────────────────
syn match trunksHeader /^[A-Z][a-z][^:]*:/
syn match trunksHeader /^Head:/ nextgroup=trunksSymbolicRef,trunksHash skipwhite
syn match trunksHeader /^Push:\|^Merge:\|^Rebase:/ nextgroup=trunksSymbolicRef skipwhite
syn match trunksHelpHeader /^Help:/ nextgroup=trunksHelpTag skipwhite
syn match trunksHelpTag /\S\+/ contained

syn match trunksSymbolicRef /\.\@!\%(\.\.\@!\|[^[:space:][:cntrl:]\:.]\)\+\.\@<!/ contained
syn match trunksHash /\S\@<!\x\{4,\}\S\@!/ contained

" ── Commit count indicators on Head: line (↓N = behind/pull, ↑N = ahead/push)
syn match trunksCommitsBehind /↓\d\+/
syn match trunksCommitsAhead  /↑\d\+/

" ── Section headings ─────────────────────────────────────────────────────────
syn region trunksUnstagedSection start=/^Unstaged (\d\+)$/ end=/^$\|^Staged / fold
  \ contains=trunksUnstagedHeading,trunksCount,trunksUnstagedModifier
syn region trunksStagedSection   start=/^Staged (\d\+)$/   end=/^$/ fold
  \ contains=trunksStagedHeading,trunksCount,trunksStagedModifier

" \ze ends the match before ' (' so only the word is highlighted
syn match trunksUnstagedHeading /^Unstaged\ze (/ contained
syn match trunksStagedHeading   /^Staged\ze (/   contained
syn match trunksCount           /(\d\+)/hs=s+1,he=e-1 contained

syn match trunksUnstagedModifier /^[MADRCU?] / contained containedin=trunksUnstagedSection
syn match trunksStagedModifier   /^[MADRCU?] / contained containedin=trunksStagedSection

" ── Diff stat ────────────────────────────────────────────────────────────────
syn match trunksDiffStat /^\d\+ file[s]\? changed.*$/

" ── Fallback definitions if vim-fugitive is not installed ─────────────────────
" These are no-ops when fugitive is already loaded (hi def link only sets if
" the group has not been defined yet).
hi def link fugitiveHeader          Label
hi def link fugitiveHelpHeader      Label
hi def link fugitiveHelpTag         Tag
hi def link fugitiveHeading         PreProc
hi def link fugitiveUntrackedHeading PreCondit
hi def link fugitiveUnstagedHeading Macro
hi def link fugitiveStagedHeading   Include
hi def link fugitiveModifier        Type
hi def link fugitiveUntrackedModifier StorageClass
hi def link fugitiveUnstagedModifier  Structure
hi def link fugitiveStagedModifier    Typedef
hi def link fugitiveHash            Identifier
hi def link fugitiveSymbolicRef     Function
hi def link fugitiveCount           Number

" ── Trunks highlight groups – fall back to fugitive equivalents ───────────────
hi def link trunksHeader          fugitiveHeader
hi def link trunksHelpHeader      fugitiveHelpHeader
hi def link trunksHelpTag         fugitiveHelpTag
hi def link trunksUnstagedHeading fugitiveUnstagedHeading
hi def link trunksStagedHeading   fugitiveStagedHeading
hi def link trunksCount           fugitiveCount
hi def link trunksUnstagedModifier fugitiveUnstagedModifier
hi def link trunksStagedModifier  fugitiveStagedModifier
hi def link trunksHash            fugitiveHash
hi def link trunksSymbolicRef     fugitiveSymbolicRef
hi def link trunksDiffStat        Comment

" Commit count indicators have no fugitive equivalent
hi def link trunksCommitsBehind WarningMsg
hi def link trunksCommitsAhead  Special

let b:current_syntax = "trunks"
