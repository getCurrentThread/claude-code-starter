# Keeps a session in bypassPermissions. Registered for PreToolUse and PermissionRequest.
#
# Manual, Accept Edits or Auto: PreToolUse answers "ask" so a permission request is raised
# even where the mode would approve the call itself, and PermissionRequest allows it and
# switches the session back to bypassPermissions.
#
# Guards:
# - Acts only in default, acceptEdits and auto. Plan, dontAsk, bypassPermissions and any
#   unknown mode pass through, so plan mode is never left mid-plan.
# - Never touches EnterPlanMode, ExitPlanMode or AskUserQuestion, or calls inside subagents.
# - Asks and switches at most once until bypass mode is seen again. If the switch does not
#   take (bypass unavailable, disabled by policy, or ignored by Claude Code), the session
#   falls back to normal prompts instead of looping.
# - Forces "ask" only in interactive sessions: under -p an ask is a denial.
# Any error ends in exit 0 with no output, which leaves Claude Code's own behavior in place.

try {
  $in = [Console]::In.ReadToEnd() | ConvertFrom-Json

  $session = "$($in.session_id)" -replace '[^A-Za-z0-9_-]', ''
  if (-not $session) { exit 0 }
  if ($in.agent_id) { exit 0 }
  if (-not $in.tool_name -or $in.tool_name -in @('AskUserQuestion', 'EnterPlanMode', 'ExitPlanMode')) { exit 0 }

  $state = Join-Path ([IO.Path]::GetTempPath()) 'claude-stay-bypass'
  $asked = Join-Path $state "$session.asked"
  $switched = Join-Path $state "$session.switched"

  if ($in.permission_mode -eq 'bypassPermissions') {
    Remove-Item -LiteralPath $asked, $switched -Force -ErrorAction SilentlyContinue
    exit 0
  }
  if ($in.permission_mode -notin @('default', 'acceptEdits', 'auto')) { exit 0 }

  New-Item -ItemType Directory -Force -Path $state -ErrorAction Stop | Out-Null

  switch ($in.hook_event_name) {
    'PreToolUse' {
      if ($env:CLAUDE_CODE_ENTRYPOINT -ne 'cli') { exit 0 }
      if ((Test-Path -LiteralPath $asked) -or (Test-Path -LiteralPath $switched)) { exit 0 }
      New-Item -ItemType File -Force -Path $asked -ErrorAction Stop | Out-Null
      '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"Returning to bypassPermissions mode"}}'
    }
    'PermissionRequest' {
      if (Test-Path -LiteralPath $switched) { exit 0 }
      New-Item -ItemType File -Force -Path $switched -ErrorAction Stop | Out-Null
      '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow","updatedPermissions":[{"type":"setMode","mode":"bypassPermissions","destination":"session"}]}}}'
    }
  }
} catch { }
exit 0
