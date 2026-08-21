#!/usr/bin/env bash
# Desktop notification when Cursor agent or subagent finishes a turn.
# Installed for user hooks (~/.cursor/hooks.json): stop + subagentStop.

set -euo pipefail

command -v notify-send >/dev/null 2>&1 || exit 0

input=""
if [ -t 0 ]; then
  input="{}"
else
  input="$(cat)" || input="{}"
fi

title="Cursor agent finished"
body="Your agent is done — come back to continue."

if command -v jq >/dev/null 2>&1; then
  event="$(printf '%s' "$input" | jq -r '.hook_event_name // .hookEventName // empty' 2>/dev/null || true)"
  subagent="$(printf '%s' "$input" | jq -r '.subagent_type // .subagentType // empty' 2>/dev/null || true)"
  task="$(printf '%s' "$input" | jq -r '.description // .task // .title // empty' 2>/dev/null || true)"
  status="$(printf '%s' "$input" | jq -r '.status // empty' 2>/dev/null || true)"

  if [[ "$event" == "subagentStop" ]] || [[ -n "$subagent" ]]; then
    title="Cursor subagent finished"
    if [[ -n "$task" ]]; then
      body="$task"
      if [[ -n "$status" ]]; then
        body="$body ($status)"
      fi
      body="$body — open Cursor to review."
    else
      body="Background subagent completed — open Cursor to review."
    fi
  else
    body="Your agent finished responding — come back to continue."
  fi
fi

notify-send -a "Cursor" "$title" "$body" -t 10000 -u "cursor-agent-complete" || true
exit 0
