# Third-party components

This repository ships **no third-party code**. It contains configuration fragments, a
procedure document, and one launcher script of its own (`scripts/Start-ClaudeTeam.ps1`, MIT,
same as the rest of this repo). The three optional components below are installed by their own
official installers or by winget, straight from their upstream repositories, at the version those
repositories publish. Nothing is vendored, mirrored, or re-hosted here.

## CC-statusline

- Upstream: https://github.com/AwesomeJun/CC-statusline
- License: MIT
- What it installs: a status line renderer (`awesome-statusline.ps1` on Windows, a shell
  script on macOS/Linux) into your Claude Code config directory, and the `statusLine` key
  in `settings.json`.
- Invoked by this repo as:
  - Windows: `irm https://raw.githubusercontent.com/AwesomeJun/CC-statusline/main/install.ps1 | iex`
  - macOS/Linux: `curl -fsSL https://raw.githubusercontent.com/AwesomeJun/CC-statusline/main/install.sh | bash`

## RTK (Rust Token Killer)

- Upstream: https://github.com/rtk-ai/rtk
- License: Apache License 2.0
- What it installs: the `rtk` binary, a `PreToolUse` Bash hook in `settings.json`, and
  `RTK.md` in your Claude Code config directory. `rtk init -g` also appends an `@RTK.md`
  import to your global `CLAUDE.md`.
- Invoked by this repo as: `rtk init -g`, after you install the binary per upstream
  instructions.

## psmux

- Upstream: https://github.com/psmux/psmux
- License: MIT
- What it installs: `psmux.exe`, `pmux.exe`, and `tmux.exe` (a tmux-compatible terminal
  multiplexer for Windows) as a winget portable package under
  `%LOCALAPPDATA%\Microsoft\WinGet\Packages\`, with command aliases in
  `%LOCALAPPDATA%\Microsoft\WinGet\Links`. It writes nothing to `settings.json`.
- Invoked by this repo as: `winget install --id marlocarlo.psmux --exact`, Windows only.
- Its default pane shell is PowerShell 7 (`pwsh`). If `pwsh` is absent, the bootstrap offers
  `winget install --id Microsoft.PowerShell --exact` (PowerShell is MIT-licensed, published by
  Microsoft).

All three are **opt-in**. Declining CC-statusline or RTK leaves your `settings.json` free of the
`statusLine` and `hooks` keys respectively; declining psmux leaves `teammateMode` and
`env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` unwritten. Nothing else about this setup changes.
