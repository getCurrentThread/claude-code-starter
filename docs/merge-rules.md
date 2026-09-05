# Merge rules

The bootstrap never replaces your `settings.json`. It merges a small set of keys into it and leaves
everything else exactly as it found it.

## The algorithm

```
result = deep copy of current settings   # or {} if the file does not exist

for each top-level key K in chosen_profile:
    if K in ("permissions", "env"):
        for each sub-key S in profile[K]:
            result[K][S] = profile[K][S]     # existing sub-keys not named here are kept
    else:
        result[K] = profile[K]

for each extras key the user approved:
    same rule

if the agent-teams step (4c) was accepted:
    merge profiles/agent-teams.json with the same rule
    # its "env" sub-key is merged one level deep, so your other env entries survive
```

Three properties follow, and they are the whole point:

1. **Nothing is ever deleted.** There is no branch that removes a key.
2. **`hooks` and `statusLine` pass through untouched**, because no profile file contains them. The
   upstream installers own those keys.
3. **It is idempotent.** Run it twice and the second run reports every row as `KEEP` and writes
   nothing.

## Diff statuses

| Status | Meaning |
|---|---|
| `ADD` | The key is not in your current settings. |
| `CHANGE` | The key exists with a different value. The before value is always shown. |
| `KEEP` | The key already equals the target value. Not written. |

`permissions` and `env` are compared and reported per sub-key, not as whole objects.

## Write safety

1. Back up to `settings.json.bak-<yyyyMMdd-HHmmss>` before writing.
2. Serialize, then parse the serialized text back, before it touches disk.
3. Write UTF-8 **without** a BOM. On Windows this means `[System.IO.File]::WriteAllText` with
   `New-Object System.Text.UTF8Encoding $false` — PowerShell 5.1's `Set-Content` and `>` default to
   the ANSI code page and will corrupt non-ASCII values.
4. Rollback is a file copy: `cp <backup> <settings.json>`.

## Worked examples

These are the three cases the rules have to get right. Profile: `balanced`, no extras.

### 1. No existing settings

Current: file does not exist.

| Key | Status | Before | After |
|---|---|---|---|
| `permissions.defaultMode` | `ADD` | — | `acceptEdits` |
| `model` | `ADD` | — | `opus` |
| `autoUpdatesChannel` | `ADD` | — | `latest` |
| `autoCompactEnabled` | `ADD` | — | `true` |
| `attribution` | `ADD` | — | `{"commit":"","pr":"","sessionUrl":false}` |

No backup is taken — there is nothing to back up. The bootstrap says so.

### 2. Existing settings with conflicts and unrelated keys

Current:

```json
{
  "model": "sonnet",
  "permissions": { "defaultMode": "default", "allow": ["Bash(git status)"] },
  "env": { "MY_VAR": "1" },
  "statusLine": { "type": "command", "command": "..." },
  "theme": "dark"
}
```

| Key | Status | Before | After |
|---|---|---|---|
| `permissions.defaultMode` | `CHANGE` | `default` | `acceptEdits` |
| `permissions.allow` | — | `["Bash(git status)"]` | untouched, not in the profile |
| `model` | `CHANGE` | `sonnet` | `opus` |
| `autoUpdatesChannel` | `ADD` | — | `latest` |
| `autoCompactEnabled` | `ADD` | — | `true` |
| `attribution` | `ADD` | — | `{"commit":"","pr":"","sessionUrl":false}` |
| `env.MY_VAR` | — | `1` | untouched |
| `statusLine` | — | existing | untouched |
| `theme` | — | `dark` | untouched |

Two `CHANGE` rows, both showing the before value. The user approves or declines the whole diff.

### 3. Existing settings that do not parse

Current: `settings.json` exists, contains a trailing comma.

The bootstrap **stops**. It reports the file path and the parse error, writes nothing, takes no
backup, and does not attempt a repair. Suggested next step for the user: fix the JSON by hand, or
move the file aside and re-run.
