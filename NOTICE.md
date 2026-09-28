# Third-party components

This repository ships **no third-party code**. It contains a procedure document. The one
component below is installed by its own official installer, straight from its upstream
repository. Nothing is vendored, mirrored, or re-hosted here.

## CC-statusline

- Upstream: https://github.com/AwesomeJun/CC-statusline
- License: MIT
- What it installs: a status line renderer (`awesome-statusline.ps1` on Windows, a shell
  script on macOS/Linux) into your Claude Code config directory, and the `statusLine` key
  in `settings.json`. Skipped when a `statusLine` is already configured.
- Invoked by this repo with the `m` size preset:
  - Windows: `& ([scriptblock]::Create((irm https://raw.githubusercontent.com/AwesomeJun/CC-statusline/main/install.ps1))) m`
  - macOS/Linux: `curl -fsSL https://raw.githubusercontent.com/AwesomeJun/CC-statusline/main/install.sh | bash -s -- m`
