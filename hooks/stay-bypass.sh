#!/bin/sh
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

input=$(cat) || exit 0

field() {
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$input" | jq -r --arg k "$1" '.[$k] // empty | strings' 2>/dev/null
  else
    printf '%s' "$input" | grep -o "\"$1\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | head -n 1 |
      sed 's/.*"\([^"]*\)"$/\1/'
  fi
}

event=$(field hook_event_name)
mode=$(field permission_mode)
tool=$(field tool_name)
session=$(field session_id | tr -cd 'A-Za-z0-9_-')

[ -n "$session" ] || exit 0
[ -z "$(field agent_id)" ] || exit 0
case "$tool" in
  ''|AskUserQuestion|EnterPlanMode|ExitPlanMode) exit 0 ;;
esac

state="${TMPDIR:-/tmp}/claude-stay-bypass"
asked="$state/$session.asked"
switched="$state/$session.switched"

case "$mode" in
  bypassPermissions) rm -f "$asked" "$switched" 2>/dev/null; exit 0 ;;
  default|acceptEdits|auto) ;;
  *) exit 0 ;;
esac

mkdir -p "$state" 2>/dev/null || exit 0

case "$event" in
  PreToolUse)
    [ "$CLAUDE_CODE_ENTRYPOINT" = cli ] || exit 0
    [ -e "$asked" ] || [ -e "$switched" ] && exit 0
    : > "$asked" 2>/dev/null || exit 0
    printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"Returning to bypassPermissions mode"}}'
    ;;
  PermissionRequest)
    [ -e "$switched" ] && exit 0
    : > "$switched" 2>/dev/null || exit 0
    printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow","updatedPermissions":[{"type":"setMode","mode":"bypassPermissions","destination":"session"}]}}}'
    ;;
esac
exit 0
