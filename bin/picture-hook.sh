#!/bin/bash
# Claude Code UserPromptSubmit hook. When Roost runs and this session has no picture or no notes yet,
# it adds a note that asks Claude to set them. It prints nothing in every other case.
id=$(jq -r '.session_id // empty')
[ -n "$id" ] || exit 0
missing=$(curl -s --max-time 1 http://127.0.0.1:4777/api/sessions |
  jq -r --arg id "$id" '.sessions[]? | select(.id == $id) | [if .pictureSet then empty else "a picture" end, if .notes then empty else "notes" end] | join(" and ")')
[ -n "$missing" ] || exit 0
cat <<EOF
Roost (the session strip on this Mac) has no $missing for this session yet. Session id: $id.
When the subject of this session is clear, set them as a side step with the roost skill.
If the subject is not clear yet, skip it: this note comes back with the next message. Do not mention this to the user unless it fails.
EOF
