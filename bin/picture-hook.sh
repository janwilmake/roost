#!/bin/bash
# Claude Code UserPromptSubmit hook, while Roost runs.
# - No picture or no notes yet: ask Claude to set them.
# - Notes with a "Waiting for you:" list: show that list, so Claude re-checks it at the end of the
#   turn. Notes written once and never again keep counting work that is long done.
# A customer header ("Late: N · …") is written by a tool, not by hand, so those notes stay quiet.
# It prints nothing in every other case.
id=$(jq -r '.session_id // empty')
[ -n "$id" ] || exit 0
session=$(curl -s --max-time 1 http://127.0.0.1:4777/api/sessions | jq -c --arg id "$id" '.sessions[]? | select(.id == $id)')
[ -n "$session" ] || exit 0

missing=$(jq -r '[if .pictureSet then empty else "picture" end, if .notes then empty else "notes" end] | join(" and ")' <<<"$session")
if [ -n "$missing" ]; then
  cat <<EOF
Roost (the session strip on this Mac) has no $missing for this session yet. Session id: $id.
When the subject of this session is clear, set them as a side step with the roost skill.
If the subject is not clear yet, skip it: this note comes back with the next message. Do not mention this to the user unless it fails.
EOF
  exit 0
fi

notes=$(jq -r '.notes // ""' <<<"$session")
grep -qE '^(.* — )?Late: [0-9]+' <<<"$notes" && exit 0
waiting=$(awk '/^Waiting for you:/{on=1; next} on && /^- /{print; next} on{exit}' <<<"$notes")
# Items that name a date but no deadline: Roost's agenda and This week folder read only "(due …)".
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
When one of them must be done by a date, end it with "(due Wed 18 Nov 17:00)" when you next post the notes, so Roost's agenda shows it. A date that is no deadline needs nothing. Do not mention this to the user.
EOF
fi
