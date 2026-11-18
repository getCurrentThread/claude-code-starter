# Third-party components

This repository ships **no third-party code**. It contains a procedure document. The one
component below is installed by its own official installer, straight from its upstream
repository. Nothing is vendored, mirrored, or re-hosted here.

## claude-statusline

- Upstream: https://github.com/awesomezun/claude-statusline
- License: MIT
- What it installs: a status line renderer (`awesome-statusline.ps1` on Windows, a shell
  script on macOS/Linux) into your Claude Code config directory, and the `statusLine` key
  in `settings.json`. Skipped when a `statusLine` is already configured.
- Invoked by this repo with the `m` size preset:
  - Windows: `$src = irm https://raw.githubusercontent.com/awesomezun/claude-statusline/main/install.ps1; & ([scriptblock]::Create($src.TrimStart([char]0xFEFF))) m`
  - macOS/Linux: `curl -fsSL https://raw.githubusercontent.com/awesomezun/claude-statusline/main/install.sh | bash -s -- m`
