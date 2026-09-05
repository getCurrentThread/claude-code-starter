# claude-code-starter

Set up Claude Code's global config in one paste. Pick a profile, review a diff, approve it.

한국어: [README.ko.md](README.ko.md)

---

## Use it

Paste this into Claude Code:

```
https://raw.githubusercontent.com/getCurrentThread/claude-code-starter/main/prompts/bootstrap.md
를 읽고 그 절차를 정확히 따라 내 Claude Code 전역 설정을 구성해줘.
```

Or in English:

```
Read https://raw.githubusercontent.com/getCurrentThread/claude-code-starter/main/prompts/bootstrap.md
and follow that procedure exactly to configure my global Claude Code settings.
```

Claude reads the environment, asks which profile you want, shows you a key-by-key diff, and writes
nothing until you approve it.

> **Read the procedure before you run it.** You are asking Claude to follow instructions from a URL.
> [`prompts/bootstrap.md`](prompts/bootstrap.md) is the whole thing, and it is short. To pin a
> reviewed version instead of tracking `main`, swap `main` for a tag such as `v0.1.0` in the URL.

## Profiles

| | `permissions.defaultMode` | `model` | For |
|---|---|---|---|
| **safe** | `default` — asks on first use of each tool | your plan's default | Starting point. Nothing runs unseen. |
| **balanced** | `acceptEdits` — auto-accepts edits and common filesystem commands in the working directory | `opus` | Everyday work in repos you trust. |
| **power** | `bypassPermissions` — no permission prompts | `opus` | Containers and VMs only. |

All three also set `autoUpdatesChannel: "latest"`, `autoCompactEnabled: true`, and an empty
`attribution` block, which keeps the Claude signature out of your commits and PRs.

The `power` profile asks for confirmation twice and quotes the official warning:

> `bypassPermissions` mode skips permission prompts, including for writes to protected paths such as
> `.git` and `.claude`. Only use this mode in isolated environments like containers or VMs where
> Claude Code can't cause damage.
> — [Claude Code docs](https://code.claude.com/docs/en/permissions)

## Extras, kept separate

Half the settings people copy from each other's dotfiles are not in the official settings reference —
`effortLevel`, `ultracode`, `remoteControlAtStartup`, `inputNeededNotifEnabled`,
`skipDangerousModePermissionPrompt`. They work. They are also written by Claude Code's `/config` UI
and can change between versions.

This repo keeps them in a separate opt-in step, tells you they are undocumented before you choose,
and defaults to leaving them off. [`docs/keys.md`](docs/keys.md) lists every key with its source and
what it costs you.

## Optional components

All three are opt-in, and each is installed by its own official installer or package manager. No
third-party code is vendored here.

- **[CC-statusline](https://github.com/AwesomeJun/CC-statusline)** (MIT) — status line with context
  usage, cost, and reasoning effort. Owns the `statusLine` key.
- **[RTK](https://github.com/rtk-ai/rtk)** (Apache-2.0) — a `PreToolUse` hook that compresses shell
  output before it reaches the context. Owns the `hooks` key. `rtk init -g` also appends an
  `@RTK.md` import to your global `CLAUDE.md`, which the bootstrap tells you before it runs.
- **[psmux](https://github.com/psmux/psmux)** (MIT) — Windows only. A tmux-compatible multiplexer
  written in Rust, no WSL, so agent teams open each teammate in its own pane instead of in-process.
  Installed with `winget install --id marlocarlo.psmux`. It writes nothing to `settings.json`; the
  bootstrap merges [`profiles/agent-teams.json`](profiles/agent-teams.json)
  (`env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`, `teammateMode`) and installs
  [`scripts/Start-ClaudeTeam.ps1`](scripts/Start-ClaudeTeam.ps1), which starts `claude` inside a
  psmux session. Optionally, [`scripts/Install-ClaudeWrapper.ps1`](scripts/Install-ClaudeWrapper.ps1)
  makes a plain `claude` do that by itself while `claude -p`, `claude mcp …` and friends keep
  running the real binary (reversible with `-Uninstall`). Third-party path, not supported by
  Anthropic; verified with Claude Code 2.1.261 and psmux 3.3.8. Details and troubleshooting:
  [`docs/agent-teams-windows.md`](docs/agent-teams-windows.md).

The first two run *before* the settings merge, so whatever they write survives it untouched.

## What it will not do

- Delete or overwrite a key that is not in the profile you picked
- Write anything before showing you a diff and getting a yes
- Touch a project-level `.claude/settings.json`
- Repair a `settings.json` that does not parse — it stops and tells you instead
- Write `theme`, `tui`, or permission allowlists. Use `/config` and `/permissions` for those

Every run backs up to `settings.json.bak-<timestamp>` first. Rollback is one file copy, and the
bootstrap prints the exact command for your OS when it finishes.

## Docs

- [`prompts/bootstrap.md`](prompts/bootstrap.md) — the procedure Claude follows
- [`docs/keys.md`](docs/keys.md) — every key, documented or not, with sources
- [`docs/merge-rules.md`](docs/merge-rules.md) — merge algorithm and worked examples
- [`docs/agent-teams-windows.md`](docs/agent-teams-windows.md) — agent teams in split panes on
  native Windows with psmux: how Claude Code decides, launcher, smoke test, failure signatures
- [`docs/troubleshooting.md`](docs/troubleshooting.md)

## Platform support

Verified on Windows (PowerShell). macOS and Linux paths are covered in the procedure and delegated
to the upstream installers, which support all three. The agent-teams step is Windows-specific; on
macOS and Linux the same settings fragment works with a regular tmux.

## License

MIT. See [LICENSE](LICENSE) and [NOTICE.md](NOTICE.md) for upstream attributions.
