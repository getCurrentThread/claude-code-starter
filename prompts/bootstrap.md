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
- `claude --version`.

Summarize this in a short table. This is the "before" picture the diff in Step 5 refers to.

## Step 2 — Choose a profile

Fetch all four profile files so you can show real values:

```
https://raw.githubusercontent.com/getCurrentThread/claude-code-starter/main/profiles/core.safe.json
https://raw.githubusercontent.com/getCurrentThread/claude-code-starter/main/profiles/core.balanced.json
https://raw.githubusercontent.com/getCurrentThread/claude-code-starter/main/profiles/core.power.json
https://raw.githubusercontent.com/getCurrentThread/claude-code-starter/main/profiles/extras.json
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

Both components below **write to `settings.json` themselves**. Run them here, *before* the merge in
Step 6, so the merge reads back whatever they wrote and preserves it. Ask before each one, and show
the exact command you are about to run.

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
```

Never remove a key. `hooks` and `statusLine` are absent from every profile file by design, so they
pass through untouched.

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

Then report:

- The applied profile and extras, as a short list.
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
| The user declines the diff | Change nothing. If Step 4 already ran an installer, state exactly what it changed. |
| No `settings.json` at all | Treat the current state as `{}`; there is nothing to back up. Say so. |
