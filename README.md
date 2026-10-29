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
| `skipDangerousModePermissionPrompt` | `true` — no startup confirmation for bypass mode |
| `model` | `opus` |
| `effortLevel` | `xhigh` |
| `modelSettings` | `xhigh` for `claude-opus-5-5` and `claude-sonnet-5-5` — the top-level `effortLevel` does not reach Opus 5.5 and later |
| `autoCompactEnabled` / `autoCompactWindow` | `true` / `400000` — compacts at 400K tokens |
| `autoUpdatesChannel` | `latest` |
| `remoteControlAtStartup`, `agentPushNotifEnabled`, `inputNeededNotifEnabled` | `true` |
| `attribution` | empty — no Claude signature in commits or PRs |
| `env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` | `"1"` — turns on agent teams (research preview); teammates are full Claude sessions and inherit bypass mode. Your other `env` keys are kept |

Plus a hook, [`hooks/stay-bypass`](hooks/), that sends a session back to bypass mode if you Shift+Tab
into Manual, Accept Edits, or Auto: on the next tool call it raises a permission request, allows it,
and switches the mode back. Plan mode and subagents are left alone, and if the switch does not take
(for example, bypass is disabled by policy) it backs off for the session instead of retrying.

And [CC-statusline](https://github.com/AwesomeJun/CC-statusline) at size `m`, unless you already
have a `statusLine` — then yours is left alone.

And a `## Subagent rules` section appended to your global `CLAUDE.md`: always pass `model` and
`effort` to the Agent tool and Workflow `agent()` (`haiku`/`sonnet` only; `low`/`medium`/`high`,
with `xhigh` only for long autonomous tasks or a re-run after `high` fell short) and no forks.
Skipped if the section is already there; your existing text is never rewritten.

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

`CLAUDE.md` is backed up the same way, to `CLAUDE.md.bak-<timestamp>`, when it already existed.


## License

MIT. See [LICENSE](LICENSE) and [NOTICE.md](NOTICE.md).
