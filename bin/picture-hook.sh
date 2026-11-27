#!/bin/bash
# Claude Code hook, while Roost runs. Register it on both UserPromptSubmit and Stop.
# - No picture, color or notes yet: give Claude the one command that sets them. On Stop, block the
#   end of the turn until they are set. A reminder alone was skipped turn after turn, because
#   skipping it cost nothing and nobody saw it.
# - Notes with a "Waiting for you:" list (UserPromptSubmit only): show that list, so Claude
#   re-checks it at the end of the turn. Notes written once and never again keep counting work
#   that is long done.
# A customer header ("Late: N · …") is written by a tool, not by hand, so those notes stay quiet.
# It prints nothing in every other case.
input=$(cat)
id=$(jq -r '.session_id // empty' <<<"$input")
[ -n "$id" ] || exit 0
event=$(jq -r '.hook_event_name // "UserPromptSubmit"' <<<"$input")
# Claude Code sets stop_hook_active when the turn already continues because of a Stop hook.
# One block per turn: a failed set must not keep the session from stopping.
[ "$event" = Stop ] && [ "$(jq -r '.stop_hook_active // false' <<<"$input")" = true ] && exit 0
session=$(curl -s --max-time 1 http://127.0.0.1:4777/api/sessions | jq -c --arg id "$id" '.sessions[]? | select(.id == $id)')
[ -n "$session" ] || exit 0

missing=$(jq -r '[if .pictureSet then empty else "picture" end, if .color then empty else "color" end, if .notes then empty else "notes" end] | join(" and ")' <<<"$session")
if [ -n "$missing" ]; then
  # Only the missing fields, so a picture or color the user chose stays.
  fields=$(jq -r '[
      if .pictureSet then empty else "\"emoji\": \"<one emoji for the subject>\", \"photo\": null, \"title\": \"<a few words>\"" end,
      if .color then empty else "\"color\": \"#<dark color in the hue of the picture, every channel at hex 32 or below>\"" end,
      if .notes then empty else "\"notes\": \"About: <one line on what this session is for>\"" end
    ] | join(", ")' <<<"$session")
  message="Roost (the session strip on this Mac) has no $missing for this session yet. Set them in this turn with this one command. Fill in each <…>, and write \\n for a new line in the notes. If the subject is not clear yet, pick an emoji for what the user asked; you can change it later. For one person or one organization, a photo or logo is better: see the roost skill.

curl -s -o /dev/null -w '%{http_code}\\n' -X POST -H 'content-type: application/json' --data-binary @- http://127.0.0.1:4777/api/sessions/$id <<'JSON'
{$fields}
JSON

It answers 200. Do not mention this to the user unless it fails."
  if [ "$event" = Stop ]; then
    jq -n --arg reason "$message" '{decision: "block", reason: $reason}'
  else
    printf '%s\n' "$message"
  fi
  exit 0
fi
[ "$event" = Stop ] && exit 0

notes=$(jq -r '.notes // ""' <<<"$session")
grep -qE '^(.* — )?Late: [0-9]+' <<<"$notes" && exit 0
waiting=$(awk '/^Waiting for you:/{on=1; next} on && /^- /{print; next} on{exit}' <<<"$notes")
# Items that name a date but no deadline: Roost's This week folder reads only "(due …)".
undated=$(grep -E '^- ' <<<"$notes" | grep -iE '(^|[^0-9])[0-9]{1,2} (jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)' |
  grep -viE '(due|back by|promised by|until) ')
if [ -n "$waiting" ]; then
  cat <<EOF
Roost badge for this session (id $id) counts these items under "Waiting for you":
$waiting
At the end of this turn, remove each item that is done or that the user decided, add what is new, and post the notes again (roost skill, "The last step of every turn"). Do not mention this to the user.
EOF
fi
if [ -n "$undated" ]; then
  cat <<EOF
These items in this session's Roost notes name a date but no deadline:
$undated
When one of them must be done by a date, end it with "(due Wed 18 Nov 17:00)" when you next post the notes, so Roost's This week folder shows it. A date that is no deadline needs nothing. Do not mention this to the user.
EOF
fi
