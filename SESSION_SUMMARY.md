# Cherry Battle — Session Summary

Working notes for resuming after a context compaction. Not part of the app; safe to delete.

## App
- **Cherry Battle** (internal name "StarBattle") — a Star Battle logic puzzle. SwiftUI, iOS 17+, MVVM. User-facing piece noun is dynamic ("cherry"/chosen symbol); internally "star".
- Repo: `/Users/jirofeingold/Projects/StarBattle`, GitHub `jiroikedafeingold/StarBattle`, commits go straight to `main`.
- Current version: **1.3.5 (build 43)**. Per CLAUDE.md, after every push bump build + version (patch by default) via `UpdateTargetBuildSetting` (CURRENT_PROJECT_VERSION / MARKETING_VERSION) — never edit pbxproj.

## Key files
- `PuzzleGenerator.swift` — generation + `LogicBoard` solver + difficulty grading (`band(forProfile:)`, `hardMinTier2`).
- `GameViewModel.swift` — game state, `newGame()`, prefetch queue (per-difficulty, persisted), win/hint/check.
- `GameView.swift` — Play screen, controls (`ToolButton`), difficulty picker, toasts, dialogs.
- `HintEngine.swift` — next-move hints. `RuleDiagram.swift` — mini rule diagrams. `OnboardingView`/`HelpView` — tutorial/help.
- `Localizable.xcstrings` — bulk-translate by **direct JSON edit** (script that matches keys by quote-normalization, fills only missing locales, keeps `%@`/`%lld`). 9 non-English locales: de es fr it pt-BR ru ja ko zh-Hans. Brand strings left English.
- Icon is user-supplied art at `Assets.xcassets/AppIcon.appiconset/icon.png` (1024); regenerate other sizes from it as opaque PNGs. Website at `docs/` (GitHub Pages) with a `#privacy` section; contact email **apps@feingold5.com**.

## Major features added this session
- **Beginner difficulty** (5×5, 1 star per row/col/region). `Difficulty` gained `beginner`, `boardSize`, `starsPerUnit`, `shortLabel`. Generator generalized for 1-star regions; size/stars threaded through generate/prefetch/launch/starters. Picker shows short labels Begin·Easy·Med·Hard. Header/Help/Onboarding switch "one"/"two"; tutorial shows BOTH rules with "or".
- **Win finale** redesign: pieces detonate one-by-one (random order, piece-colored bursts + residue) then banner; strong layered haptics.
- **Pieces**: bright emoji (cherry uses custom CherryView); quirky set (poop/alien/ghost/robot/unicorn/dino); larger glyphs.
- **Settings**: Haptics + Win celebration toggles. **Button press haptics** on all controls.
- **Hidden**: long-press Hint 10s = near-solve (all but one). **Deep Check**: long-press Check **3s** flags wrong dots red. `ToolButton.longPressSeconds` configurable.
- **Mark mode**: guesses never overwrite real marks; first-guess "?" ghost persists across mark-mode sessions.
- **Generation perf**: per-difficulty prefetch queue persisted to disk (instant New/switch across relaunches).
- **Difficulty tuning**: `hardMinTier2` 6→5 (gentler Medium). Medium generation **selects** boards that are gentle (tier2≤2) AND have ≥`mediumMinSmall`(4) simple (≤6-cell) regions — more footholds / simpler shapes — sampling up to `mediumSampleCap`(4), scored `small*10 - tier2`. Easy guarantees ≥6 small regions.
- **Hints** favor placing a cherry, then a move in the smallest region (still logical).
- **Difficulty switch confirmation**: switching levels mid-game asks first (picker snaps back on cancel); fresh board switches silently. Rule toast ("N piece per row, column and region") shows when crossing into/out of Beginner.

## Notable constraints / gotchas
- Medium/Hard generation is slow in the unoptimized RunCodeSnippet/sim-debug context (a single Medium ~100s+); fine in release + prefetched in background. Avoid large generation loops in snippets (they time out).
- Device-interaction subagents repeatedly hit session limits; verified mark-mode guard + splash-piece on device, deep-Check is build/logic-verified (harness couldn't reproduce the continuous long-press).
- Memories live in the Claude config memory dir (MEMORY.md index). Relevant: localization-direct-edit, app-website-conventions, app-icon-regen, cherry-battle-naming, main-actor-by-default.

## Possible follow-ups
- A precise "multiple logical paths" metric in the solver (current approach approximates it via small-region count).
- Update the `app-icon-regen` memory (icon is now user-supplied art, not the rendered board).
