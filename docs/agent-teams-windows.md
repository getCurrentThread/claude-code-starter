# Agent Teams in split panes on native Windows (psmux)

Claude Code's agent teams can show each teammate in its own terminal pane. The official docs say
this needs tmux or iTerm2 and list Windows Terminal as unsupported. On Windows, **psmux** — a
tmux-compatible multiplexer written in Rust that runs on ConPTY, no WSL — fills the tmux role well
enough that Claude Code cannot tell the difference. This page is the setup the bootstrap's optional
step 4c performs, plus how to verify it and what breaks.

**This is a third-party path.** The word "psmux" appears nowhere in Anthropic's docs, changelog, or
the `claude` binary. It works because psmux imitates tmux's command line; any Claude Code or psmux
release can change that. In-process mode (the default) is the only Anthropic-supported mode on
Windows and works in every terminal without any of this.

## Verified combination

| Component | Version | Notes |
|---|---|---|
| Windows | 11 Pro, build 26200 | Build 22523+ needed for mouse input inside panes |
| Claude Code | 2.1.261 (native `claude.exe`) | Checked 2026-09-05 |
| psmux | 3.3.8 (`marlocarlo.psmux`, winget) | Released 2026-08-18 |
| PowerShell 7 | 7.6.5, Microsoft Store (MSIX) build | psmux's default pane shell |
| Host terminal | Windows Terminal, "Windows PowerShell" 5.1 profile | The outer shell does not matter |

Result: a two-teammate smoke test split the window within 30 seconds, both teammates ran in their own
panes, messaged the lead, and shut down on request. The lead's transcript `.jsonl` was written
normally, so `--resume` works for the lead session.

## How Claude Code decides

Three things must all be true, or teammates run in-process:

1. **`teammateMode` is `"tmux"`** (or `"auto"`) in a settings file. The default has been
   `"in-process"` since v2.1.179, so being inside a multiplexer is not enough on its own.
2. **`claude` was started inside the psmux session.** Claude Code reads `TMUX` and `TMUX_PANE` at
   startup and splits *that* window. Started elsewhere in `tmux` mode, it creates an invisible
   detached server instead.
3. **A `tmux` command resolves on PATH.** psmux installs a real `tmux.exe` alias whose `-V` prints
   `tmux 3.3.8`. No shim is needed.

The bootstrap handles (1) with [`profiles/agent-teams.json`](../profiles/agent-teams.json). The
launcher script handles (2). winget handles (3).

## Setup by hand

### 1. psmux

```powershell
winget install --id marlocarlo.psmux --exact --accept-source-agreements --accept-package-agreements
```

Portable zip, user scope, no UAC. It registers three command aliases, `psmux`, `pmux`, and `tmux`,
under `%LOCALAPPDATA%\Microsoft\WinGet\Links`, which winget already keeps on your user PATH.
**Open a new terminal tab** afterwards; any `claude` started before the install caches a negative
`tmux` lookup for its lifetime.

```powershell
tmux -V      # tmux 3.3.8  /  psmux 3.3.8 (66cf613 2026-08-18)
```

### 2. PowerShell 7

psmux opens `pwsh` in every pane by default and its Claude Code guide says PowerShell 7 or later is
required for the pane-side helpers. If `pwsh` is missing:

```powershell
winget install --id Microsoft.PowerShell --exact --accept-source-agreements --accept-package-agreements
```

Recent winget builds install the Store (MSIX) package, which lands under
`C:\Program Files\WindowsApps\` and is reachable through the `pwsh` app-execution alias. That build
was the one verified above.

### 3. Settings

Add to `~/.claude/settings.json` (top-level key; the bootstrap merges this for you):

```json
{
  "env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" },
  "teammateMode": "tmux"
}
```

Do not rely on `claude --teammate-mode tmux` alone. Opening Agent View (Left arrow) makes Claude
Code re-exec itself with a fresh argv and the flag is lost (psmux #578). With the key in settings,
psmux's own `claude` wrapper stops injecting the flag, so the two never fight.

`"auto"` also picks panes inside psmux but silently degrades to in-process outside it. `"tmux"`
fails loudly at spawn time instead, which is what you want while setting this up.

### 4. Launch

Either run the launcher:

```powershell
# installed by the bootstrap to <config-dir>\scripts\
& "$env:USERPROFILE\.claude\scripts\Start-ClaudeTeam.ps1" -Dir C:\path\to\project
```

or do what it does by hand, from any Windows Terminal tab:

```powershell
cd C:\path\to\project
psmux new-session -A -s work     # status bar with [work] appears; the pane is pwsh
claude                           # inside the pane
```

The launcher refuses to nest (`TMUX` already set), checks that `psmux`, `tmux`, and `claude`
resolve, warns if `teammateMode` is not set, warns about other psmux sessions, creates the session
in the project directory, types `claude` into the first pane, and attaches. Add `-DebugLog` to start
Claude with `--debug-file %TEMP%\claude_debug.log`.

Do not start from `%USERPROFILE%` itself: Claude Code rejects executables located under its working
directory, and the winget package sits under `AppData` (claude-code #43840).

### 5. Smoke test

Type into the lead pane:

```
Spawn an agent team of exactly two teammates named alpha and beta, using the Agent tool with the
name parameter so each runs as a teammate in its own tmux pane. Do NOT use isolation: "worktree"
and do NOT use plain subagents. alpha: count the top-level items in this directory and message me
the number. beta: create smoke-beta.txt containing the single line "hello from beta" and message me
when done. Do not do either task yourself.
```

Expected within about 30 seconds: the lead pane shrinks to roughly a third of the width on the left,
alpha opens on the right, then the right column splits again for beta; pane borders show the names;
the agent panel under the lead's prompt lists both. From a second tab, not inside psmux:

```powershell
psmux list-panes -t work -F "#{pane_id} #{pane_title}"      # 3 lines
Select-String "$env:USERPROFILE\.claude\teams\session-*\config.json" -Pattern '"backendType": "tmux"'
Select-String "$env:TEMP\claude_debug.log" -Pattern 'TeammateModeSnapshot|BackendRegistry|TmuxBackend'
```

The debug log should contain `[TeammateModeSnapshot] Captured from config: tmux`,
`isInProcessEnabled: false (mode=tmux, insideTmux=true` and `[TmuxBackend] Created teammate pane`.

Shut down with `Ask alpha and beta to shut down.` — both panes close. Then `/exit`, `exit` the pane
shell, and `psmux ls` shows nothing. `psmux kill-server` stops everything if something lingers.

## Keys

psmux's prefix is `Ctrl+b`, the same as tmux, and it collides with Claude Code's own `Ctrl+B`
(run task in background). Claude Code notices tmux and shows `ctrl+b ctrl+b (twice)`; press it
twice. Or move the prefix in `~/.psmux.conf`:

```
set -g prefix C-a
unbind C-b
bind C-a send-prefix
```

| Keys | Action |
|---|---|
| Prefix, then Arrow | Move between panes (typing in a teammate pane talks to that teammate) |
| Prefix `z` | Zoom the current pane |
| Prefix `q` | Show pane numbers |
| Prefix `d` | Detach; `psmux attach -t work` returns |
| PgUp / PgDn | Scroll inside Claude Code (the wheel arrives as arrow keys, psmux #597) |

Alt combinations can be swallowed by Windows Terminal.

## Troubleshooting

Start with `-DebugLog` and read `%TEMP%\claude_debug.log`.

| Symptom | Cause | Fix |
|---|---|---|
| Names appear in the agent panel, no panes open | `teammateMode` missing or `in-process` | Add the key to `~/.claude/settings.json`; restart `claude` |
| Log says `Captured from CLI override` then teammates go in-process after Agent View | Only the CLI flag was used | Put the key in settings (psmux #578) |
| Status line says `View teammates: tmux -L claude-swarm-<pid> a` | `claude` was not started inside the psmux pane | Start it in the pane; `tmux -L claude-swarm-<pid> kill-server` to remove the stray server |
| `Command 'tmux' not found or is in an unsafe location` or `you need tmux which requires WSL` | `tmux -V` failed: PATH not refreshed, cwd is `%USERPROFILE%`, or Defender quarantined `psmux.exe` (#631) | New tab; start from a project folder; check Protection history |
| `isInProcessEnabled: true (non-interactive session)` | `claude -p` or stdout is not a TTY | Interactive `claude` only; `-p` never spawns teammates |
| `Failed to send command to pane` / `subagent_teammate_pane_unavailable` | psmux command failure, usually more than one session | `psmux kill-server`, keep exactly one session (psmux #627) |
| Claude used worktree agents or subagents instead | Worktree agents always run in-process on Windows | Re-prompt; add to `CLAUDE.md`: *For agent teams, spawn teammates with the Agent tool `name` parameter; never use `isolation: "worktree"`.* |
| `winget upgrade` says access is denied | A psmux server is running | `psmux kill-server` first |
| A folder cannot be deleted while a pane is open | The pane's conhost holds the source directory (psmux #630) | Close the pane |

**Fallback.** `claude --teammate-mode in-process` for one session, or set the key to
`"in-process"`. In-process teammates work in any terminal but do not survive `/resume` or `/rewind`.

## Things to know before using this for real work

- **Permissions are inherited.** Teammates take the lead's permission mode at spawn. Under the
  `power` profile that is three or more unattended agents with `bypassPermissions`. Prefer
  `acceptEdits` in repositories you care about.
- **Cost.** Each teammate is a full `claude.exe` with its own context window and idle CPU.
- **Any subagent Claude names becomes a teammate** while the env var is `1`, even when you did not
  ask for a team. Set it to `0` to switch off without restarting.
- **One session.** Keep a single psmux session while a team runs; bare `%N` pane targets can land in
  another session (psmux #627, open on 3.3.8).
- **Cosmetic.** Every spawn forces `pane-border-status top` (claude-code #89202). Mouse-wheel
  scrolling inside Claude Code arrives as arrow keys (psmux #597).
- **Korean / CJK input.** psmux's FAQ says IME composition and paste work, and every Korean-IME
  issue in its tracker is closed. Composition inside Claude Code's input box has no field report;
  try it in a plain pane first.
- **Updates.** No Claude Code release tests against psmux. If panes stop working after an update,
  re-run the smoke test and check both trackers before changing anything.

## macOS and Linux

The same settings fragment applies with real tmux: `brew install tmux` / `apt install tmux`, start
`claude` inside a tmux session, done. iTerm2 users can set `"teammateMode": "iterm2"` with the
`it2` CLI instead. Nothing in this page beyond the settings key is needed there.

## Sources

- Claude Code docs: [agent teams](https://code.claude.com/docs/en/agent-teams),
  [`teammateMode`](https://code.claude.com/docs/en/settings-reference#teammatemode)
- psmux: [repository](https://github.com/psmux/psmux),
  [Claude Code guide](https://github.com/psmux/psmux/blob/master/docs/claude-code.md),
  [winget manifest `marlocarlo.psmux`](https://github.com/microsoft/winget-pkgs/tree/master/manifests/m/marlocarlo/psmux)
- Issues referenced: psmux [#578](https://github.com/psmux/psmux/issues/578),
  [#597](https://github.com/psmux/psmux/issues/597), [#627](https://github.com/psmux/psmux/issues/627),
  [#630](https://github.com/psmux/psmux/issues/630), [#631](https://github.com/psmux/psmux/issues/631);
  claude-code [#43840](https://github.com/anthropics/claude-code/issues/43840),
  [#89202](https://github.com/anthropics/claude-code/issues/89202)
