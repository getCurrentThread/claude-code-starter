# claude-code-starter

Set up Claude Code's global config in one paste. No questions asked.

한국어: [README.ko.md](README.ko.md)

---

## Use it

Paste this into Claude Code:

```
Read https://raw.githubusercontent.com/getCurrentThread/claude-code-starter/main/prompts/bootstrap.md
and follow that procedure exactly to configure my global Claude Code settings.
```

Claude backs up your `settings.json`, merges in the settings below, installs a status line, and
reports what changed. It does not ask you anything along the way.

> **Read [`prompts/bootstrap.md`](prompts/bootstrap.md) before you run it.** It is short, and it
> turns on `bypassPermissions`. To pin a reviewed version instead of tracking `main`, swap `main`
> for a tag in the URL.

## What it sets

| Key | Value |
|---|---|
| `permissions.defaultMode` | `bypassPermissions` — no permission prompts |
| `permissions.disableAutoMode` | `disable` — auto mode leaves the Shift+Tab cycle |
| `skipDangerousModePermissionPrompt` | `true` — no startup confirmation for bypass mode |
| `model` | `opus` |
| `effortLevel` / `ultracode` | `xhigh` / `true` |
| `modelSettings` | `xhigh` for `claude-opus-5-5` and `claude-sonnet-5-5` — the top-level `effortLevel` does not reach Opus 5.5 and later |
| `autoCompactEnabled` / `autoCompactWindow` | `true` / `400000` — compacts at 400K tokens |
| `autoUpdatesChannel` | `latest` |
| `remoteControlAtStartup`, `agentPushNotifEnabled`, `inputNeededNotifEnabled` | `true` |
| `attribution` | empty — no Claude signature in commits or PRs |

Plus a `PermissionRequest` hook, [`hooks/stay-bypass`](hooks/), that sends a session back to bypass
mode if you Shift+Tab into Manual or Accept Edits: the first time a permission prompt would appear,
it allows the request and switches the mode back. Plan mode is left alone.

And [CC-statusline](https://github.com/AwesomeJun/CC-statusline) at size `m`, unless you already
have a `statusLine` — then yours is left alone.

Keys not in this table are kept as they are, and a `settings.json` that does not parse is left
untouched.

> `bypassPermissions` mode skips permission prompts, including for writes to protected paths such as
> `.git` and `.claude`. Only use this mode in isolated environments like containers or VMs where
> Claude Code can't cause damage.
> — [Claude Code docs](https://code.claude.com/docs/en/permissions)

## Roll back

Every run backs up to `settings.json.bak-<timestamp>` first, and the final report prints the exact
restore command. By hand:

```powershell
Copy-Item "$env:USERPROFILE\.claude\settings.json.bak-<timestamp>" "$env:USERPROFILE\.claude\settings.json" -Force
```

```bash
cp ~/.claude/settings.json.bak-<timestamp> ~/.claude/settings.json
```

## Upgrading from v0.1.0

RTK is no longer installed. An existing RTK setup is left in place. To remove it, delete its
`PreToolUse` entry under `hooks` in `settings.json` and the `@RTK.md` line in your global
`CLAUDE.md`.

## License

MIT. See [LICENSE](LICENSE) and [NOTICE.md](NOTICE.md).
