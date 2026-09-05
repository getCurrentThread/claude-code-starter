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
normally, so `--resume` works for the lead session. The optional `claude` wrapper (below) was
verified from PowerShell 5.1 and Git Bash inside Windows Terminal, and from mintty (`git-bash.exe`).

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
launcher script handles (2), and the optional wrapper makes a plain `claude` go through the
launcher. winget handles (3).

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

If you accepted the wrapper in the bootstrap (or ran `Install-ClaudeWrapper.ps1`), a plain `claude`
in a project folder is all it takes; see [Make `claude` start in psmux](#make-claude-start-in-psmux)
below. Otherwise run the launcher:

```powershell
# installed by the bootstrap to <config-dir>\scripts\
& "$env:USERPROFILE\.claude\scripts\Start-ClaudeTeam.ps1" -Dir C:\path\to\project
```

or do the equivalent by hand, from any Windows Terminal tab:

```powershell
cd C:\path\to\project
psmux new-session -A -s work     # any name (the launcher uses the project folder's name); the pane is pwsh
claude                           # inside the pane
```

What the launcher does: refuses to nest (`TMUX` already set); checks that `psmux`, `tmux`, and
`claude.exe` resolve; warns if `teammateMode` is not `tmux`/`auto` (project `.claude\settings*.json`
first, then the user file, like Claude Code); warns about other psmux sessions; creates a session
named after the project folder (`-Session` to override); starts `claude.exe` as the pane's first
process through `pwsh -EncodedCommand`, so arguments with quotes, spaces, or Korean text arrive
intact; attaches. If a session of that name already exists **in the same folder** and no arguments
were given, you are re-attached to it (that is how you get back after `Ctrl+b d`). If arguments were
given, or the session belongs to a different folder with the same name, a `<name>-2` session is
created and a WARN line says so.
When claude exits the pane closes and the session ends, like a plain `claude` would (after an error
exit the pane waits for Enter so you can read it). `-KeepPane` leaves an interactive shell in the
pane instead; `-DebugLog` adds `--debug-file %TEMP%\claude_debug.log`; `-ClaudeArgs` forwards
arguments.

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
psmux ls                                                       # session name = project folder name
psmux list-panes -t <session> -F "#{pane_id} #{pane_title}"    # 3 lines
Select-String "$env:USERPROFILE\.claude\teams\session-*\config.json" -Pattern '"backendType": "tmux"'
Select-String "$env:TEMP\claude_debug.log" -Pattern 'TeammateModeSnapshot|BackendRegistry|TmuxBackend'
```

The debug log should contain `[TeammateModeSnapshot] Captured from config: tmux`,
`isInProcessEnabled: false (mode=tmux, insideTmux=true` and `[TmuxBackend] Created teammate pane`.

Shut down with `Ask alpha and beta to shut down.` — both panes close. Then `/exit`: with the
launcher the pane closes with it and `psmux ls` shows nothing; after a manual start, `exit` the
pane shell as well. `psmux kill-server` stops everything if something lingers.

## Make `claude` start in psmux

`scripts/Install-ClaudeWrapper.ps1` makes the command you already type do the right thing. After
it runs, in a **new** terminal:

| You type | What runs |
|---|---|
| `claude`, `claude --resume`, `claude -c`, `claude "prompt"`, `claude --model opus` | The launcher: a psmux session in the current folder with claude inside it |
| `claude -p …`, `claude --version`, `claude --help`, `claude --bare`, `claude --bg`, `claude --teammate-mode …`, `claude --cloud …`, `claude --environment …`, `claude -w … --tmux` | The real `claude.exe`, unchanged |
| `claude mcp …`, `doctor`, `auth`, `plugin`, `agents`, `install`, `update`/`upgrade` and the other subcommands, also with options in front (`claude --verbose mcp list`) | The real `claude.exe`, unchanged |
| Anything with stdin/stdout piped, from inside a Claude Code session (`CLAUDECODE` set), or already inside a psmux pane (`TMUX` set) | The real `claude.exe`, unchanged |
| `claude` while psmux is not installed or `teammateMode` is not `tmux`/`auto` (project `.claude\settings*.json` first, then the user file) | The real `claude.exe`, with a one-line note on stderr |

A subcommand is recognised as any bare word that equals a subcommand name, wherever it appears, so
an unquoted prompt such as `claude explain the mcp setup` runs `claude mcp` (which is what
`claude.exe` itself would do). Quote prompts: `claude "explain the mcp setup"`.

Where the session appears depends on the terminal:

| Terminal | Behaviour |
|---|---|
| Windows Terminal, conhost, VS Code: PowerShell 5.1, PowerShell 7, Git Bash | psmux attaches in the same tab (Git Bash checks that its tty is a Windows console, `/dev/cons*`) |
| mintty (the window `git-bash.exe` opens) | A new Windows Terminal window opens with the session; mintty is not a Windows console, which the psmux client needs |
| cmd.exe | Through the PATH shim only. If `claude.exe`'s folder is on the *machine* PATH, cmd.exe keeps finding the real binary first; the installer tells you when that is the case |

Arguments reach `claude.exe` unchanged in PowerShell 7 and Git Bash. Windows PowerShell 5.1 re-quotes
native arguments itself: on the pass-through path it drops embedded double quotes and empty
arguments (the same thing happens without the wrapper), so use `pwsh` for `claude -p` with a JSON
schema or a quoted prompt. Interactive starts are not affected: the launcher hands the arguments to
the pane through `-EncodedCommand`.

What the installer changes, all reversible with `Install-ClaudeWrapper.ps1 -Uninstall`:

- `<config-dir>\bin\`: `claude-wrapper.ps1` (the decision logic), `claude.cmd` (cmd/PowerShell PATH
  shim; runs the wrapper with `pwsh` when present), `claude` (Git Bash shim), `claude-team.cmd`
  (explicit launcher). `Start-ClaudeTeam.ps1` and the installer itself are copied to
  `<config-dir>\scripts`, which is where the rollback command points.
- User PATH: `<config-dir>\bin` moved to the front. The registry value keeps its type, so
  `%VAR%` entries stay unexpanded.
- A marked `function claude { … }` block in `Documents\WindowsPowerShell\profile.ps1` and
  `Documents\PowerShell\profile.ps1`, and a `claude() { … }` block in `~/.bashrc` plus a line that
  sources it in the bash login file (`~/.bash_profile`, `~/.bash_login` or `~/.profile`, whichever
  exists first; `~/.bash_profile` is created with the same two lines Git for Windows generates when
  none does). The functions are what give the wrapper precedence in interactive shells; `-NoProfiles`
  skips them. Files keep their encoding (UTF-8 BOM, ANSI, UTF-16) and line endings; a file the
  installer created is deleted again by `-Uninstall` when nothing else was added to it, and a file
  whose marker lines were damaged by hand makes the installer stop instead of guessing.

Teammate spawning is unaffected: Claude Code launches teammates by the absolute path of
`claude.exe`, never by the bare name. Auto-update replaces `claude.exe` in place and the wrapper
resolves it fresh on every call.

Knobs (a value of `0`, `false`, `no` or `off` counts as unset): `CLAUDE_NO_PSMUX=1` runs the real
binary once (`CLAUDE_NO_PSMUX=1 claude` in bash, `$env:CLAUDE_NO_PSMUX=1; claude` in PowerShell).
`CLAUDE_WRAPPER_DRYRUN=1 claude …` prints the decision without running anything.
`CLAUDE_WRAPPER_LOG=<file>` appends one line per call with the inputs and the decision (give a
Windows path, `C:\Temp\claude-wrapper.log`, so the PowerShell half can write to it from Git Bash).
`CLAUDE_REAL_EXE=<path>` pins the binary. The Git Bash shim's own switches (`MSYS_NO_PATHCONV`,
`MSYS2_ARG_CONV_EXCL`, `CLAUDE_WRAPPER_NEWWINDOW`) are removed from the environment before
`claude.exe` starts, so Claude Code's Bash tool keeps normal path conversion.

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
| Prefix `d` | Detach; `psmux attach -t <session>` returns, and so does a plain `claude` typed in the same folder |
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
| Plain `claude` still opens the real binary after installing the wrapper | Old shell (profile not reloaded), profile scripts blocked by execution policy, or cmd.exe with `claude.exe` on the machine PATH | New terminal; `Get-Command claude` should say `Function`; `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`; use PowerShell or Git Bash instead of cmd.exe |
| Wrapper runs the real binary and says why on stderr | psmux missing, `teammateMode` not `tmux`/`auto`, or the launcher file is missing | Fix the named cause; `CLAUDE_WRAPPER_DRYRUN=1 claude` shows the decision |
| `claude` typed in a pane behaves as if the wrapper were absent | Expected: inside psmux (`TMUX` set) the wrapper always passes through | Nothing to fix |
| The psmux session appears and closes at once, nothing printed | `claude.exe` exited immediately: an unquoted prompt contained a subcommand word, or a startup error | `CLAUDE_WRAPPER_DRYRUN=1 claude …` shows the decision; `Start-ClaudeTeam.ps1 -KeepPane` keeps the pane open to read the error |
| A `<folder>-2` session was created instead of re-attaching | Arguments were given, or another project with the same folder name already has a session | Expected; `psmux attach -t <folder>` reaches the old one, `psmux kill-server` when done |
| A second `claude` in the same folder silently re-attached and ignored `--model` | Only an argument-less `claude` re-attaches; with arguments a new session is started | Detach with Ctrl+b d, then `claude --model …` starts `<folder>-2` |

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
  another session (psmux #627, open on 3.3.8). Because sessions are named after the project folder,
  a plain `claude` in a *second* project starts a second session; the launcher prints a WARN listing
  the others but does not stop. For that second session use `CLAUDE_NO_PSMUX=1 claude` (no panes)
  or wait until the team is done.
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
