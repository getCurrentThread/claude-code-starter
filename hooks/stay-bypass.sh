#!/bin/sh
# PermissionRequest hook: a permission prompt only appears outside bypass mode, so
# allow the request and switch the session back to bypassPermissions.
# Plan mode and the interactive tools (AskUserQuestion, ExitPlanMode) are left alone.
input=$(cat)
field() {
  printf '%s' "$input" | grep -o "\"$1\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | head -n 1 | sed 's/.*"\([^"]*\)"$/\1/'
}
case "$(field permission_mode)" in
  default|acceptEdits) ;;
  *) exit 0 ;;
esac
case "$(field tool_name)" in
  AskUserQuestion|ExitPlanMode|'') exit 0 ;;
esac
printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow","updatedPermissions":[{"type":"setMode","mode":"bypassPermissions","destination":"session"}]}}}'
