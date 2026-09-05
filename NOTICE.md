# Third-party components

This repository ships **no third-party code**. It contains configuration fragments and a
procedure document. The two optional components below are installed by their own official
installers, straight from their upstream repositories, at the version those repositories
publish. Nothing is vendored, mirrored, or re-hosted here.

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

Both are **opt-in**. Declining either leaves your `settings.json` free of the `statusLine`
and `hooks` keys respectively, and nothing else about this setup changes.
