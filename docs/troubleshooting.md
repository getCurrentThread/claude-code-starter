# Troubleshooting

## The settings did not take effect

Restart Claude Code. `model`, `hooks`, and `statusLine` are read at session start. `/config` and
`/model` change the running session without touching the file.

## I want my old settings back

Every run backs up first. Restore the newest backup:

```powershell
# Windows
Copy-Item "$env:USERPROFILE\.claude\settings.json.bak-<timestamp>" "$env:USERPROFILE\.claude\settings.json" -Force
```

```bash
# macOS / Linux
cp ~/.claude/settings.json.bak-<timestamp> ~/.claude/settings.json
```

The CC-statusline installer takes its own backup with a different name
(`settings.json.backup-<timestamp>`), so after a full run you may have two. Pick by timestamp.

## The bootstrap stopped and said my settings.json does not parse

That is deliberate. Repairing a broken config file by guessing is how people lose settings. Open the
file, fix the JSON (a trailing comma and an unquoted key are the usual causes), and re-run. If you
do not care about the contents, move it aside and re-run — the bootstrap treats a missing file as an
empty config.

## Korean or other non-ASCII text in settings.json turned into garbage

Something wrote the file with the Windows ANSI code page. PowerShell 5.1's `Set-Content` and `>`
both do this by default. Restore from a backup and make sure the write goes through
`[System.IO.File]::WriteAllText($path, $json, (New-Object System.Text.UTF8Encoding $false))`.

## The status line is blank or shows an error

- Check that the script the `statusLine.command` points at actually exists.
- On Windows the renderer needs to be UTF-8 with BOM for PowerShell 5.1 to parse it — the upstream
  installer handles this. If you copied the file around by hand, re-run the installer.
- Re-run the installer with a different size preset (`xs` `s` `m` `l` `xl`) if the line is too wide
  for your terminal.
- Upstream issues: https://github.com/AwesomeJun/CC-statusline

## `rtk` is installed but the hook does nothing

- Restart Claude Code. Hooks are registered at session start.
- Confirm `rtk --version` resolves in the same shell Claude Code uses. On Windows, a binary in
  `%USERPROFILE%\.local\bin` needs that directory on PATH.
- `rtk init -g` is what writes the hook. If `settings.json` has no `hooks` key, it did not run.
- Upstream issues: https://github.com/rtk-ai/rtk

## `bypassPermissions` is set but Claude still asks for permission

Either your organization disabled it (`permissions.disableBypassPermissionsMode`), or you hit one of
the actions no mode auto-approves. See
[permission modes](https://code.claude.com/docs/en/permission-modes).

## An extras key stopped working after an update

Expected. Extras are undocumented `/config`-managed keys and can change between versions. Remove the
key, or set it again through `/config`. See [keys.md](keys.md).
