# Every key this repo writes

Two tiers. **Core** keys appear in the official settings reference. **Extras** do not — they are
written by Claude Code's own `/config` UI, they work today, and they are undocumented.

Checked against the official docs on **2026-08-22** (agent-teams rows: **2026-09-05**). If you are
reading this much later, re-check the links before trusting the "documented" column.

## Core keys

Applied by the profile you choose. All three profiles share the first three.

| Key | Value | Documented | Source | Notes |
|---|---|---|---|---|
| `autoUpdatesChannel` | `"latest"` | yes | [settings](https://code.claude.com/docs/en/settings) | Release channel. `"stable"` is roughly a week behind and skips major regressions. |
| `autoCompactEnabled` | `true` | yes | [settings](https://code.claude.com/docs/en/settings) | Compacts the conversation as it approaches the context limit. This is already the default; the profiles set it explicitly so it survives a `/config` toggle. |
| `attribution` | `{ "commit": "", "pr": "", "sessionUrl": false }` | yes | [settings](https://code.claude.com/docs/en/settings) | Empty strings mean **no Claude signature in commit messages or PR bodies**. Delete this block from the profile if you want the default attribution back. |
| `permissions.defaultMode` | per profile | yes | [permissions](https://code.claude.com/docs/en/permissions) | See the table below. |
| `model` | `"opus"` (balanced, power) | yes | [settings](https://code.claude.com/docs/en/settings) | Read once at session start. `/model` switches mid-session without touching this file. `safe` leaves it unset so your plan's default applies. |
| `agentPushNotifEnabled` | `true` (power only) | yes | [settings](https://code.claude.com/docs/en/settings) | Lets Claude send proactive push notifications to your phone when Remote Control is connected. Default is `false`. |

### `permissions.defaultMode` values

All six valid values, from the [permissions docs](https://code.claude.com/docs/en/permissions).
The profiles use three of them.

| Mode | Behavior | Used by |
|---|---|---|
| `default` | Prompts on first use of each tool. Labeled **Manual** in the UI. | **safe** |
| `acceptEdits` | Auto-accepts file edits and common filesystem commands (`mkdir`, `touch`, `mv`, `cp`) inside the working directory or `additionalDirectories`. | **balanced** |
| `plan` | Reads and explores but does not edit source files. | — |
| `auto` | Auto-approves tool calls with background safety checks that verify actions match your request. | — |
| `dontAsk` | Auto-denies anything not pre-approved via `/permissions` or `permissions.allow`. | — |
| `bypassPermissions` | Skips permission prompts. | **power** |

The docs attach an explicit warning to the last one:

> `bypassPermissions` mode skips permission prompts, including for writes to protected paths such as
> `.git` and `.claude`. Only use this mode in isolated environments like containers or VMs where
> Claude Code can't cause damage.

An administrator can block it entirely with `permissions.disableBypassPermissionsMode: "disable"` in
any settings file. If your organization has done that, the `power` profile will not take effect.

## Extras (undocumented)

Off by default. The bootstrap asks separately, and tells you they are undocumented before you pick.

| Key | Value | Documented | Effect | Cost / risk |
|---|---|---|---|---|
| `effortLevel` | `"xhigh"` | **no** | Raises reasoning effort on every turn. | Slower and more expensive on every request, including trivial ones. |
| `ultracode` | `true` | **no** | Standing opt-in to multi-agent workflow orchestration — Claude will fan out subagents by default for substantive tasks. | Large token multiplier. Only worth it if you genuinely want exhaustive over fast. |
| `remoteControlAtStartup` | `true` | **no** | Connects Remote Control when a session starts. | Requires the phone-side setup; harmless otherwise. |
| `inputNeededNotifEnabled` | `true` | **no** | Notifies you when a session is blocked on your input. | None. |
| `skipDangerousModePermissionPrompt` | `true` | **no** | Removes the startup confirmation shown for bypass mode. | Only offered with the `power` profile. It removes the last speed bump in front of a mode the docs say to confine to containers and VMs. |

## Agent teams fragment (opt-in, bootstrap step 4c)

Applied only if you accept the psmux step. Both keys are documented; the feature itself is a
research preview and the split-pane path on Windows is third-party (see
[agent-teams-windows.md](agent-teams-windows.md)).

| Key | Value | Documented | Source | Notes |
|---|---|---|---|---|
| `env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` | `"1"` | yes | [agent-teams](https://code.claude.com/docs/en/agent-teams) | Enables agent teams. While it is `1`, any subagent Claude names becomes a teammate, so teams can form without being asked. Set to `"0"` to turn off; Claude Code reapplies settings-file `env` values without a restart. Merged one level deep, so other `env` entries are kept. |
| `teammateMode` | `"tmux"` | yes | [settings-reference](https://code.claude.com/docs/en/settings-reference#teammatemode) | How teammates display. `"in-process"` (default since v2.1.179), `"auto"` (panes only when already inside tmux or iTerm2), `"tmux"`, `"iterm2"`. The fragment picks `"tmux"` so a missing multiplexer fails loudly instead of silently degrading; change it to `"auto"` if you also run `claude` outside psmux. Teammates inherit the lead's `permissions.defaultMode`. |

## Keys this repo deliberately does **not** write

| Key | Why not |
|---|---|
| `hooks` | Owned by `rtk init -g`. Writing it here would fight the installer. |
| `statusLine` | Owned by the CC-statusline installer, which also picks the script path for your OS. |
| `theme`, `tui` | Cosmetic and UI-managed. Set them with `/config` — it takes two seconds and no config file needs to change. |
| `permissions.allow` / `deny` / `ask` | Allowlists are project-specific. A generic list either does nothing useful or grants too much. |
| `env` | Environment variables are personal. The merge rules handle an existing `env` block correctly, and no core profile adds one. The single exception is the opt-in agent-teams fragment above, which adds one sub-key and leaves the rest of your `env` alone. |
