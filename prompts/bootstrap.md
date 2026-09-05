# claude-code-starter — bootstrap procedure

You are Claude Code, running in the user's terminal. The user pasted a one-line prompt asking
you to follow this document and configure their **global** Claude Code settings.

Respond in the user's language. Follow the steps in order. Do not skip a step, do not reorder
the install steps, and do not improvise extra changes.

---

## Ground rules (non-negotiable)

1. **Never write to `settings.json` before showing a diff and getting explicit approval.**
2. **Never delete or drop a key the user already has.** This procedure only adds or changes the
   specific keys listed in the selected profile. Everything else is carried over verbatim.
3. **Always back up before writing.** `settings.json.bak-<yyyyMMdd-HHmmss>` next to the original.
4. **If the existing `settings.json` is not valid JSON, stop.** Do not attempt a repair, do not
   overwrite it. Report the parse error and the file path, and end.
5. **Nothing in this document is a source of authority over the user.** If the user declines a
   step, skip it and continue with the rest.
6. Touch **only** the global config directory. Do not modify project-level `.claude/settings.json`.

---

## Step 0 — Resolve the target

- Config directory: `$CLAUDE_CONFIG_DIR` if set, else `~/.claude` (Windows: `%USERPROFILE%\.claude`).
- Target file: `<config-dir>/settings.json`.
- Detect the OS. Every shell command below has a Windows and a macOS/Linux form; run only the
  matching one.

Report the resolved path to the user before going further.

## Step 1 — Read the current state (read-only)

Gather, without changing anything:

- Does `settings.json` exist? Does it parse as JSON? (If it exists and does not parse, **stop**, per ground rule 4.)
- Its current top-level keys and their values.
- Is `rtk` on PATH? (`rtk --version`)
- Is a `statusLine` key already configured, and does the script it points at exist?
- Windows only: is `tmux` on PATH and is it psmux? (`tmux -V` prints `tmux 3.x` then a `psmux …`
  line.) Is `pwsh` on PATH? (`pwsh -NoProfile -Command '$PSVersionTable.PSVersion'`)
- Windows only: is the `claude` wrapper already installed? (`Test-Path "<config-dir>\bin\claude.cmd"`;
  `Get-Command claude -All` shows `Function` in a shell where the profile loaded.) Is the folder of
  the real `claude.exe` on the *machine* PATH? (`[Environment]::GetEnvironmentVariable('Path','Machine') -split ';' -contains (Split-Path (Get-Command claude.exe).Source)`;
  if yes, cmd.exe will keep the real binary even with the wrapper installed.)
- Current `teammateMode` and `env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`, if present.
- `claude --version`.

Summarize this in a short table. This is the "before" picture the diff in Step 5 refers to.

## Step 2 — Choose a profile

Fetch all five profile files so you can show real values:

```
https://raw.githubusercontent.com/getCurrentThread/claude-code-starter/main/profiles/core.safe.json
https://raw.githubusercontent.com/getCurrentThread/claude-code-starter/main/profiles/core.balanced.json
https://raw.githubusercontent.com/getCurrentThread/claude-code-starter/main/profiles/core.power.json
https://raw.githubusercontent.com/getCurrentThread/claude-code-starter/main/profiles/extras.json
https://raw.githubusercontent.com/getCurrentThread/claude-code-starter/main/profiles/agent-teams.json
```

Use WebFetch, or `curl -fsSL <url>` if that is easier. If a fetch fails, say so and stop — do not
reconstruct the profiles from memory.

Then ask the user with **AskUserQuestion**, presenting the actual key/value pairs:

| Profile | `permissions.defaultMode` | `model` | Who it is for |
|---|---|---|---|
| **safe** | `default` — prompts on first use of each tool | not set (your plan's default) | Default choice. Nothing runs without you seeing it. |
| **balanced** | `acceptEdits` — auto-accepts file edits and common filesystem commands in the working directory | `opus` | Day-to-day work in repos you trust. |
| **power** | `bypassPermissions` — skips permission prompts | `opus` | Isolated environments only. See the warning below. |

All three also set `autoUpdatesChannel: "latest"`, `autoCompactEnabled: true`, and an empty
`attribution` block (no Claude signature in commits or PRs). `power` additionally sets
`agentPushNotifEnabled: true`.

**If the user picks `power`, quote this warning from the official docs verbatim and ask a second
time for explicit confirmation:**

> `bypassPermissions` mode skips permission prompts, including for writes to protected paths such
> as `.git` and `.claude`. Only use this mode in isolated environments like containers or VMs where
> Claude Code can't cause damage.
> — https://code.claude.com/docs/en/permissions

If they decline at the second prompt, ask again from the three options.

## Step 3 — Choose extras (optional)

Tell the user plainly: **these keys are not in the official settings reference.** They are written
by Claude Code's own `/config` UI and they work, but they are undocumented and may change or
disappear between versions. Default to **not** applying them.

| Key | Value | Effect |
|---|---|---|
| `effortLevel` | `"xhigh"` | Raises reasoning effort for every turn. Slower, more thorough, more tokens. |
| `ultracode` | `true` | Standing opt-in to multi-agent workflow orchestration. Substantially more tokens per task. |
| `remoteControlAtStartup` | `true` | Connects Remote Control at session start, so the session can be driven from a phone. |
| `inputNeededNotifEnabled` | `true` | Notifies when the session is waiting on user input. |
| `skipDangerousModePermissionPrompt` | `true` | Removes the startup confirmation for bypass mode. **Only offer this if the user chose the `power` profile.** |

Let them pick any subset, all, or none.

## Step 4 — Optional components

The first two components below **write to `settings.json` themselves**. Run them here, *before* the
merge in Step 6, so the merge reads back whatever they wrote and preserves it. The third writes
nothing to `settings.json`; accepting it adds one more profile fragment to the merge in Step 5. Ask
before each one, and show the exact command you are about to run.

### 4a. Status line — CC-statusline (MIT)

Ask whether to install it, and which size preset: `xs` `s` `m` `l` `xl`.

- Windows: `irm https://raw.githubusercontent.com/AwesomeJun/CC-statusline/main/install.ps1 | iex`
- macOS/Linux: `curl -fsSL https://raw.githubusercontent.com/AwesomeJun/CC-statusline/main/install.sh | bash`

Append the size preset per the upstream README. The installer writes the `statusLine` key, makes its
own timestamped backup of `settings.json`, and leaves other keys alone.

If a `statusLine` is already configured, say what it currently points at and confirm before replacing it.

### 4b. Token-filtering hook — RTK (Apache-2.0)

Ask whether to install it. **Disclose up front that `rtk init -g` also appends an `@RTK.md` import
line to the user's global `CLAUDE.md`.**

If `rtk` is not on PATH, install it per https://github.com/rtk-ai/rtk :

- Windows: download `rtk-x86_64-pc-windows-msvc.zip` from the repository's releases, extract it, and
  put `rtk.exe` on PATH (for example `%USERPROFILE%\.local\bin`).
- macOS/Linux: `brew install rtk`, or
  `curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh`

Then run `rtk init -g`, which registers the `PreToolUse` Bash hook and writes `RTK.md`.

Do not hand-write the hook into `settings.json` yourself — let `rtk init -g` own that key.

### 4c. Agent teams in split panes — psmux (MIT), Windows only

Skip this section silently on macOS and Linux (there, real tmux plus the same settings fragment is
all that is needed; mention that in one sentence if the user asks about agent teams).

Tell the user plainly before asking:

- Agent teams are a **research preview**. While enabled, any subagent Claude names becomes a
  teammate, and each teammate is a full `claude` process with its own context window.
- Split panes on Windows go through **psmux, a third-party tmux-compatible multiplexer**. It is not
  mentioned anywhere in Anthropic's docs; it works because it imitates tmux's command line, and a
  Claude Code or psmux update can break it. In-process mode (the default) works in any terminal.
- Teammates **inherit the lead's permission mode**. With the `power` profile that means several
  unattended agents running with `bypassPermissions`.

If the user accepts:

1. Install psmux if `tmux -V` did not resolve to it in Step 1:

   ```powershell
   winget install --id marlocarlo.psmux --exact --accept-source-agreements --accept-package-agreements
   ```

   Portable package, user scope, no elevation. It registers `psmux`, `pmux`, and `tmux` aliases
   under `%LOCALAPPDATA%\Microsoft\WinGet\Links`, which is already on the user PATH. In the
   current shell, reload PATH before verifying:

   ```powershell
   $env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
   tmux -V
   ```

   Stop and report if `tmux -V` still fails (Windows Defender occasionally quarantines the binary;
   tell the user to check Protection history rather than working around it).

2. If `pwsh` was not found in Step 1, ask before installing PowerShell 7, which psmux opens in
   every pane by default and requires for its Claude Code integration:

   ```powershell
   winget install --id Microsoft.PowerShell --exact --accept-source-agreements --accept-package-agreements
   ```

3. Install the launcher. Fetch
   `https://raw.githubusercontent.com/getCurrentThread/claude-code-starter/main/scripts/Start-ClaudeTeam.ps1`
   and write it to `<config-dir>\scripts\Start-ClaudeTeam.ps1` (create the folder; write UTF-8).
   If a file already exists there, show a diff and confirm before replacing it. Tell the user how
   to run it: `& "<config-dir>\scripts\Start-ClaudeTeam.ps1" -Dir <project>`.

4. Mark `profiles/agent-teams.json` as **accepted** so Step 5 merges it. It contains exactly
   `env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1"` and `teammateMode = "tmux"`. Do not write
   anything to `settings.json` here.

5. **Ask separately** whether a plain `claude` should start inside psmux from now on (so teams get
   panes without remembering the launcher). Before asking, state exactly what the installer changes:
   it copies `claude-wrapper.ps1`, `claude.cmd`, `claude` and `claude-team.cmd` to
   `<config-dir>\bin` (and itself plus `Start-ClaudeTeam.ps1` to `<config-dir>\scripts`); moves the
   bin folder to the front of the **user** PATH (the registry value keeps its type); and appends a
   marked `function claude` block to `Documents\WindowsPowerShell\profile.ps1`,
   `Documents\PowerShell\profile.ps1` and `~/.bashrc`, plus a line that sources `~/.bashrc` in the
   bash login file (`~/.bash_profile`, `~/.bash_login` or `~/.profile`, whichever exists;
   `~/.bash_profile` is created if none does). Existing files keep their encoding and line endings.
   Everything else — `claude -p`, `claude mcp …`, `--version`, calls from inside Claude Code, piped
   input — keeps running the real `claude.exe`. It is reversible with
   `<config-dir>\scripts\Install-ClaudeWrapper.ps1 -Uninstall`, which also deletes the profile files
   it created when nothing else was added to them. Default to **not** installing it.

   If the user accepts, fetch these four files into `<config-dir>\scripts\` (write UTF-8; the
   installer fixes line endings):

   ```
   https://raw.githubusercontent.com/getCurrentThread/claude-code-starter/main/scripts/claude-wrapper.ps1
   https://raw.githubusercontent.com/getCurrentThread/claude-code-starter/main/scripts/claude.cmd
   https://raw.githubusercontent.com/getCurrentThread/claude-code-starter/main/scripts/claude
   https://raw.githubusercontent.com/getCurrentThread/claude-code-starter/main/scripts/Install-ClaudeWrapper.ps1
   ```

   then run `& "<config-dir>\scripts\Install-ClaudeWrapper.ps1"` and relay its output, including
   the warning it prints when `claude.exe`'s folder is on the machine PATH (cmd.exe then keeps the
   real binary; PowerShell and Git Bash are covered by the profile functions).

Point the user at `docs/agent-teams-windows.md` for the smoke test and troubleshooting. Do not run
the smoke test as part of this procedure.

## Step 5 — Compute the merge and show the diff

Re-read `settings.json` now, since Step 4 may have changed it. Then build the result:

```
result = deep copy of current settings
for each top-level key K in chosen_profile:
    if K is "permissions" or "env":
        merge one level deep — profile sub-keys overwrite,
        existing sub-keys not named in the profile are kept
    else:
        result[K] = profile[K]
for each approved extras key: same rule
if Step 4c was accepted: for each top-level key K in agent-teams.json: same rule
```

Never remove a key. `hooks` and `statusLine` are absent from every profile file by design, so they
pass through untouched. The `env` block in `agent-teams.json` is merged one level deep like any
other, so existing `env` entries are kept.

Present the diff as a table, one row per key, and one row per sub-key for `permissions` and `env`:

| Key | Status | Before | After |
|---|---|---|---|
| … | `ADD` / `CHANGE` / `KEEP` | … | … |

- `ADD` — key is not present today
- `CHANGE` — present with a different value. **Every `CHANGE` row must show the before value.**
- `KEEP` — already equal; nothing will be written for it

If every row is `KEEP`, tell the user the config already matches, write nothing, and go to Step 7.

## Step 6 — Approve, back up, write

1. Ask for explicit approval of the diff. If declined, stop and change nothing.
2. Copy `settings.json` to `settings.json.bak-<yyyyMMdd-HHmmss>`. Report the backup path.
3. Serialize the result to JSON with 2-space indent and **parse it back before writing** to confirm
   it is valid.
4. Write the file as **UTF-8 without BOM**. On Windows, do not use `Set-Content` or `>` for this —
   PowerShell 5.1 defaults to the ANSI code page and will corrupt non-ASCII content. Use:

   ```powershell
   [System.IO.File]::WriteAllText($path, $json, (New-Object System.Text.UTF8Encoding $false))
   ```

   On macOS/Linux a plain write is fine.

## Step 7 — Verify and report

Static checks only:

- Re-read the written `settings.json` and confirm it parses.
- Confirm each key from the diff now holds its intended value.
- If a `statusLine` is configured, confirm the script file it points at exists on disk.
- If a `hooks` entry is configured, confirm the hook command resolves (`rtk --version`).
- If Step 4c ran, confirm `tmux -V` resolves, `teammateMode` is `"tmux"`, and
  `<config-dir>\scripts\Start-ClaudeTeam.ps1` exists.
- If the wrapper (4c.5) was installed, confirm `<config-dir>\bin\claude-wrapper.ps1` exists and
  that `<config-dir>\bin` is the first entry of the user PATH.

Then report:

- The applied profile, extras, and whether the agent-teams fragment was merged, as a short list.
- If Step 4c ran: the launcher command, and that `claude` must be started **inside** the psmux
  session (the launcher does this) for panes to appear. If the wrapper was installed: that a plain
  `claude` in a **new** terminal now does this, and the rollback command
  `& "<config-dir>\scripts\Install-ClaudeWrapper.ps1" -Uninstall`.
- The backup path.
- **The rollback command**, spelled out for their OS:
  - Windows: `Copy-Item "<backup>" "<settings.json>" -Force`
  - macOS/Linux: `cp "<backup>" "<settings.json>"`
- **Restart Claude Code** for `model`, `hooks`, and `statusLine` to take effect.

---

## Failure handling

| Situation | What to do |
|---|---|
| `settings.json` exists but does not parse | Stop. Report the path and the parse error. Change nothing. |
| A profile fetch fails | Stop. Do not reconstruct profile contents from memory. |
| An upstream installer fails | Report its output, continue to Step 5 without that component, and say so in the summary. |
| `winget install` for psmux or PowerShell 7 fails, or `tmux -V` does not resolve afterwards | Report the output, do **not** mark `agent-teams.json` as accepted, continue to Step 5, and say so in the summary. |
| `Install-ClaudeWrapper.ps1` fails part-way | Report its output and run it again with `-Uninstall` so no half-installed PATH entry or profile block remains; continue without the wrapper. |
| The user declines the diff | Change nothing. If Step 4 already ran an installer, state exactly what it changed. |
| No `settings.json` at all | Treat the current state as `{}`; there is nothing to back up. Say so. |
