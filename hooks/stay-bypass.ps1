# PermissionRequest hook: a permission prompt only appears outside bypass mode, so
# allow the request and switch the session back to bypassPermissions.
# Plan mode and the interactive tools (AskUserQuestion, ExitPlanMode) are left alone.
try { $in = [Console]::In.ReadToEnd() | ConvertFrom-Json } catch { exit 0 }
if ($in.permission_mode -notin @('default', 'acceptEdits')) { exit 0 }
if (-not $in.tool_name -or $in.tool_name -in @('AskUserQuestion', 'ExitPlanMode')) { exit 0 }
'{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow","updatedPermissions":[{"type":"setMode","mode":"bypassPermissions","destination":"session"}]}}}'
